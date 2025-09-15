import Foundation
import SwiftUI

// Ensure SharedCore types are accessible
// TL* types defined in SharedCore.swift sho    func applySearchFilter(to contestants: [TLContestant]) -> [TLContestant] {ld be available in same module

// MARK: - Export & Import System Types

enum ExportFormat: CaseIterable {
    case text, json, markdown, csv
    
    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .json: return "json"
        case .markdown: return "md"
        case .csv: return "csv"
        }
    }
    
    var displayName: String {
        switch self {
        case .text: return "Plain Text"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        case .csv: return "CSV"
        }
    }
}

// MARK: - Analysis & Statistics Types

struct TierDistributionData: Identifiable, Sendable {
    let id = UUID()
    let tier: String
    let count: Int
    let percentage: Double
}

struct TierAnalysisData: Sendable {
    let totalContestants: Int
    let tierDistribution: [TierDistributionData]
    let mostPopulatedTier: String?
    let leastPopulatedTier: String?
    let balanceScore: Double
    let insights: [String]
    let unrankedCount: Int
    
    static let empty = TierAnalysisData(
        totalContestants: 0,
        tierDistribution: [],
        mostPopulatedTier: nil,
        leastPopulatedTier: nil,
        balanceScore: 0,
        insights: ["No contestants found - add some contestants to see analysis"],
        unrankedCount: 0
    )
}

@MainActor
final class AppState: ObservableObject {
    @Published var tiers: TLTiers = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
    @Published var tierOrder: [String] = ["S","A","B","C","D","F"]
    @Published var searchQuery: String = ""
    @Published var activeFilter: FilterType = .all
    @Published var currentToast: ToastMessage? = nil
    @Published var quickRankTarget: TLContestant? = nil
    // Head-to-Head
    @Published var h2hActive: Bool = false
    @Published var h2hPool: [TLContestant] = []
    @Published var h2hPair: (TLContestant, TLContestant)? = nil
    @Published var h2hRecords: [String: TLH2HRecord] = [:]
    
    // Enhanced Persistence
    @Published var hasUnsavedChanges: Bool = false
    @Published var lastSavedTime: Date? = nil
    @Published var currentFileName: String? = nil
    
    // Progress Tracking & Visual Feedback
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    @Published var operationProgress: Double = 0.0
    @Published var dragTargetTier: String? = nil
    @Published var draggingId: String? = nil
    @Published var isProcessingSearch: Bool = false
    
    private let storageKey = "Tiercade.tiers.v1"
    nonisolated(unsafe) private var autosaveTimer: Timer?
    private let autosaveInterval: TimeInterval = 30.0 // Auto-save every 30 seconds

    private var history = TLHistory<TLTiers>(stack: [], index: 0, limit: 80)

    init() {
        if !load() {
            seed()
        }
        history = TLHistoryLogic.initHistory(tiers, limit: 80)
        setupAutosave()
    }
    
    deinit {
        autosaveTimer?.invalidate()
    }
    
    private func setupAutosave() {
        autosaveTimer = Timer.scheduledTimer(withTimeInterval: autosaveInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if self.hasUnsavedChanges {
                    self.autoSave()
                }
            }
        }
    }
    
    private func markAsChanged() {
        hasUnsavedChanges = true
    }

    func seed() {
        tiers["unranked"] = [
            TLContestant(id: "kyle48", name: "Kyle Fraser", season: "48", thumbUri: nil),
            TLContestant(id: "parvati", name: "Parvati Shallow", season: "Multiple", thumbUri: nil),
            TLContestant(id: "sandra", name: "Sandra Diaz-Twine", season: "Multiple", thumbUri: nil)
        ]
    }

    func move(_ id: String, to tier: String) {
        let next = TLTierLogic.moveContestant(tiers, contestantId: id, targetTierName: tier)
        guard next != tiers else { return }
        tiers = next
        history = TLHistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
    }

    func clearTier(_ tier: String) {
        var next = tiers
        guard let moving = next[tier], !moving.isEmpty else { return }
        next[tier] = []
        next["unranked", default: []].append(contentsOf: moving)
        tiers = next
        history = TLHistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        showInfoToast("Tier Cleared", message: "Moved all contestants from \(tier) tier to unranked")
    }

    func undo() { 
        guard TLHistoryLogic.canUndo(history) else { return }
        history = TLHistoryLogic.undo(history)
        tiers = TLHistoryLogic.current(history)
        markAsChanged()
        showInfoToast("Undone", message: "Last action has been undone")
    }
    
    func redo() { 
        guard TLHistoryLogic.canRedo(history) else { return }
        history = TLHistoryLogic.redo(history)
        tiers = TLHistoryLogic.current(history)
        markAsChanged()
        showInfoToast("Redone", message: "Action has been redone")
    }
    var canUndo: Bool { TLHistoryLogic.canUndo(history) }
    var canRedo: Bool { TLHistoryLogic.canRedo(history) }
    
    // MARK: - Search & Filter
    func filteredContestants(for tier: String) -> [TLContestant] {
        let contestants = tiers[tier] ?? []
        return applySearchFilter(to: contestants)
    }
    
    func allContestants() -> [TLContestant] {
        switch activeFilter {
        case .all:
            let all = tierOrder.flatMap { tiers[$0] ?? [] } + (tiers["unranked"] ?? [])
            return applySearchFilter(to: all)
        case .ranked:
            let ranked = tierOrder.flatMap { tiers[$0] ?? [] }
            return applySearchFilter(to: ranked)
        case .unranked:
            let unranked = tiers["unranked"] ?? []
            return applySearchFilter(to: unranked)
        }
    }
    
    func applySearchFilter(to contestants: [TLContestant]) -> [TLContestant] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return contestants }
        
        // Show processing indicator for large datasets
        if contestants.count > 50 {
            setSearchProcessing(true)
        }
        
        let filteredResults = contestants.filter { contestant in
            let name = (contestant.name ?? "").lowercased()
            let season = (contestant.season ?? "").lowercased()
            let id = contestant.id.lowercased()
            
            return name.contains(query) || season.contains(query) || id.contains(query)
        }
        
        if contestants.count > 50 {
            setSearchProcessing(false)
        }
        
        return filteredResults
    }
    
    // MARK: - Toast System
    
    func showToast(type: ToastType, title: String, message: String? = nil, duration: TimeInterval = 3.0) {
        let toast = ToastMessage(type: type, title: title, message: message, duration: duration)
        currentToast = toast
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else { return }
            if self.currentToast?.id == toast.id {
                self.dismissToast()
            }
        }
    }
    
    func dismissToast() {
        currentToast = nil
    }
    
    func showSuccessToast(_ title: String, message: String? = nil) {
        showToast(type: .success, title: title, message: message)
    }
    
    func showErrorToast(_ title: String, message: String? = nil) {
        showToast(type: .error, title: title, message: message)
    }
    
    func showInfoToast(_ title: String, message: String? = nil) {
        showToast(type: .info, title: title, message: message)
    }
    
    func showWarningToast(_ title: String, message: String? = nil) {
        showToast(type: .warning, title: title, message: message)
    }

    func reset() {
        tiers = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
        seed()
        history = TLHistoryLogic.initHistory(tiers, limit: history.limit)
        markAsChanged()
    }

    // MARK: - Add Contestant
    func addContestant(id: String, name: String? = nil, season: String? = nil, thumbUri: String? = nil) {
        let c = TLContestant(id: id, name: name, season: season, thumbUri: thumbUri)
        var next = tiers
        next["unranked", default: []].append(c)
        tiers = next
        history = TLHistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        showSuccessToast("Added", message: "Added \(name ?? id) to Unranked")
    }
    
    func randomize() {
        // Collect all contestants from all tiers
        var allContestants: [TLContestant] = []
        for tierName in tierOrder + ["unranked"] {
            allContestants.append(contentsOf: tiers[tierName] ?? [])
        }
        
        // Clear all tiers
        var newTiers = tiers
        for tierName in tierOrder + ["unranked"] {
            newTiers[tierName] = []
        }
        
        // Shuffle and redistribute
        allContestants.shuffle()
        let tiersToFill = tierOrder // Don't include unranked in randomization
        let contestantsPerTier = max(1, allContestants.count / tiersToFill.count)
        
        for (index, contestant) in allContestants.enumerated() {
            let tierIndex = min(index / contestantsPerTier, tiersToFill.count - 1)
            let tierName = tiersToFill[tierIndex]
            newTiers[tierName, default: []].append(contestant)
        }
        
        tiers = newTiers
        history = TLHistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        
        showSuccessToast("Tiers Randomized", message: "All contestants have been redistributed randomly")
    }

    // MARK: - Progress Tracking & Visual Feedback
    
    func setLoading(_ loading: Bool, message: String = "") {
        isLoading = loading
        loadingMessage = message
        if loading {
            operationProgress = 0.0
        }
    }
    
    func updateProgress(_ progress: Double) {
        operationProgress = min(max(progress, 0.0), 1.0)
    }
    
    func setDragTarget(_ tierName: String?) {
        dragTargetTier = tierName
    }

    func setDragging(_ id: String?) {
        draggingId = id
    }
    
    func setSearchProcessing(_ processing: Bool) {
        isProcessingSearch = processing
    }
    
    // Helper method to wrap async operations with loading indicators
    func withLoadingIndicator<T: Sendable>(message: String, operation: () async throws -> T) async rethrows -> T {
        setLoading(true, message: message)
        defer { setLoading(false) }
        return try await operation()
    }

    // MARK: - Enhanced Persistence
    
    @discardableResult
    func save() -> Bool {
        do {
            let data = try JSONEncoder().encode(tiers)
            UserDefaults.standard.set(data, forKey: storageKey)
            hasUnsavedChanges = false
            lastSavedTime = Date()
            showSuccessToast("Saved", message: "Tier list saved successfully")
            return true
        } catch {
            print("Save failed: \(error)")
            showErrorToast("Save Failed", message: "Could not save tier list")
            return false
        }
    }
    
    @discardableResult
    func autoSave() -> Bool {
        guard hasUnsavedChanges else { return true }
        return save()
    }
    
    @discardableResult
    func saveToFile(named fileName: String) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            
            let saveData = TierListSaveData(
                tiers: tiers,
                createdDate: Date(),
                appVersion: "1.0"
            )
            
            let data = try encoder.encode(saveData)
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
            
            try data.write(to: fileURL)
            
            currentFileName = fileName
            hasUnsavedChanges = false
            lastSavedTime = Date()
            
            showSuccessToast("File Saved", message: "Saved as \(fileName).json")
            return true
        } catch {
            print("File save failed: \(error)")
            showErrorToast("Save Failed", message: "Could not save \(fileName).json")
            return false
        }
    }

    @discardableResult
    func load() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return false }
        do {
            let decoded = try JSONDecoder().decode(TLTiers.self, from: data)
            tiers = decoded
            history = TLHistoryLogic.initHistory(tiers, limit: history.limit)
            hasUnsavedChanges = false
            lastSavedTime = UserDefaults.standard.object(forKey: "\(storageKey).timestamp") as? Date
            showSuccessToast("Loaded", message: "Tier list loaded successfully")
            return true
        } catch {
            print("Load failed: \(error)")
            showErrorToast("Load Failed", message: "Could not load tier list")
            return false
        }
    }
    
    @discardableResult
    func loadFromFile(named fileName: String) -> Bool {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
            
            let data = try Data(contentsOf: fileURL)
            let saveData = try JSONDecoder().decode(TierListSaveData.self, from: data)
            
            tiers = saveData.tiers
            history = TLHistoryLogic.initHistory(tiers, limit: history.limit)
            currentFileName = fileName
            hasUnsavedChanges = false
            lastSavedTime = saveData.createdDate
            
            showSuccessToast("File Loaded", message: "Loaded \(fileName).json")
            return true
        } catch {
            print("File load failed: \(error)")
            showErrorToast("Load Failed", message: "Could not load \(fileName).json")
            return false
        }
    }
    
    func getAvailableSaveFiles() -> [String] {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURLs = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: nil)
            return fileURLs
                .filter { $0.pathExtension == "json" }
                .map { $0.deletingPathExtension().lastPathComponent }
                .sorted()
        } catch {
            print("Error listing save files: \(error)")
            return []
        }
    }
    
    func deleteSaveFile(named fileName: String) -> Bool {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            print("Error deleting save file: \(error)")
            return false
        }
    }
    
    // MARK: - Async File Operations with Progress Tracking
    
    func saveToFileAsync(named fileName: String) async -> Bool {
        return await withLoadingIndicator(message: "Saving \(fileName)...") {
            updateProgress(0.2)
            
            do {
                let saveData = TierListSaveData(
                    tiers: tiers,
                    createdDate: Date(),
                    appVersion: "1.0"
                )
                updateProgress(0.4)
                
                let data = try JSONEncoder().encode(saveData)
                updateProgress(0.6)
                
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
                updateProgress(0.8)
                
                try data.write(to: fileURL)
                
                await MainActor.run {
                    currentFileName = fileName
                    hasUnsavedChanges = false
                    lastSavedTime = Date()
                }
                updateProgress(1.0)
                
                showSuccessToast("File Saved", message: "Saved \(fileName).json")
                return true
            } catch {
                print("File save failed: \(error)")
                showErrorToast("Save Failed", message: "Could not save \(fileName).json")
                return false
            }
        }
    }
    
    func loadFromFileAsync(named fileName: String) async -> Bool {
        return await withLoadingIndicator(message: "Loading \(fileName)...") {
            updateProgress(0.2)
            
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
                updateProgress(0.4)
                
                let data = try Data(contentsOf: fileURL)
                updateProgress(0.6)
                
                let saveData = try JSONDecoder().decode(TierListSaveData.self, from: data)
                updateProgress(0.8)
                
                await MainActor.run {
                    tiers = saveData.tiers
                    history = TLHistoryLogic.initHistory(tiers, limit: history.limit)
                    currentFileName = fileName
                    hasUnsavedChanges = false
                    lastSavedTime = saveData.createdDate
                }
                updateProgress(1.0)
                
                showSuccessToast("File Loaded", message: "Loaded \(fileName).json")
                return true
            } catch {
                print("File load failed: \(error)")
                showErrorToast("Load Failed", message: "Could not load \(fileName).json")
                return false
            }
        }
    }

    // MARK: - Export & Import System
    
    func exportToFormat(_ format: ExportFormat, group: String = "All", themeName: String = "Default") async -> (Data, String)? {
        return await withLoadingIndicator(message: "Exporting \(format.displayName)...") {
            updateProgress(0.2)
            
            let cfg: TLTierConfig = [
                "S": (name: "S", description: nil),
                "A": (name: "A", description: nil),
                "B": (name: "B", description: nil),
                "C": (name: "C", description: nil),
                "D": (name: "D", description: nil),
                "F": (name: "F", description: nil)
            ]
            updateProgress(0.4)
            
            let result: String
            let fileName: String
            switch format {
            case .text:
                result = TLExportFormatter.generate(group: group, date: .now, themeName: themeName, tiers: tiers, tierConfig: cfg)
                fileName = "tier_list.txt"
            case .json:
                result = exportToJSON(group: group, themeName: themeName)
                fileName = "tier_list.json"
            case .markdown:
                result = exportToMarkdown(group: group, themeName: themeName, tierConfig: cfg)
                fileName = "tier_list.md"
            case .csv:
                result = exportToCSV(group: group, themeName: themeName)
                fileName = "tier_list.csv"
            }
            updateProgress(0.8)
            
            guard let data = result.data(using: .utf8) else {
                showErrorToast("Export Failed", message: "Could not convert content to data")
                return nil
            }
            
            updateProgress(1.0)
            showSuccessToast("Export Complete", message: "Exported as \(format.displayName)")
            return (data, fileName)
        }
    }
    
    private func exportToJSON(group: String, themeName: String) -> String {
        let exportData = [
            "metadata": [
                "group": group,
                "theme": themeName,
                "exportDate": ISO8601DateFormatter().string(from: Date()),
                "appVersion": "1.0"
            ],
            "tierOrder": tierOrder,
            "tiers": tiers.mapValues { contestants in
                contestants.map { ["id": $0.id, "name": $0.name ?? "", "season": $0.season ?? ""] }
            }
        ] as [String: Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
    
    private func exportToMarkdown(group: String, themeName: String, tierConfig: TLTierConfig) -> String {
        var markdown = "# My Survivor Tier Ranking - \(group)\n\n"
        markdown += "**Theme:** \(themeName)  \n"
        markdown += "**Date:** \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none))\n\n"
        
        for tierName in tierOrder {
            guard let contestants = tiers[tierName], !contestants.isEmpty,
                  let cfg = tierConfig[tierName] else { continue }
            
            markdown += "## \(cfg.name) Tier\n\n"
            for contestant in contestants {
                markdown += "- **\(contestant.name ?? contestant.id)** (Season \(contestant.season ?? "?"))\n"
            }
            markdown += "\n"
        }
        
        if let unranked = tiers["unranked"], !unranked.isEmpty {
            markdown += "## Unranked\n\n"
            for contestant in unranked {
                markdown += "- \(contestant.name ?? contestant.id) (Season \(contestant.season ?? "?"))\n"
            }
        }
        
        return markdown
    }
    
    private func exportToCSV(group: String, themeName: String) -> String {
        var csv = "Name,Season,Tier\n"
        
        for tierName in tierOrder {
            guard let contestants = tiers[tierName] else { continue }
            for contestant in contestants {
                let name = (contestant.name ?? contestant.id).replacingOccurrences(of: ",", with: ";")
                let season = contestant.season ?? "?"
                csv += "\"\(name)\",\"\(season)\",\"\(tierName)\"\n"
            }
        }
        
        if let unranked = tiers["unranked"] {
            for contestant in unranked {
                let name = (contestant.name ?? contestant.id).replacingOccurrences(of: ",", with: ";")
                let season = contestant.season ?? "?"
                csv += "\"\(name)\",\"\(season)\",\"Unranked\"\n"
            }
        }
        
        return csv
    }
    
    func saveExportToFile(_ content: String, format: ExportFormat, fileName: String) async -> Bool {
        return await withLoadingIndicator(message: "Saving \(format.displayName) file...") {
            updateProgress(0.3)
            
            do {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fullFileName = "\(fileName).\(format.fileExtension)"
                let fileURL = documentsPath.appendingPathComponent(fullFileName)
                updateProgress(0.7)
                
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
                updateProgress(1.0)
                
                showSuccessToast("File Saved", message: "Saved \(fullFileName)")
                return true
            } catch {
                showErrorToast("Save Failed", message: "Could not save \(format.displayName) file")
                return false
            }
        }
    }
    
    func importFromJSON(_ jsonString: String) async -> Bool {
        return await withLoadingIndicator(message: "Importing JSON data...") {
            updateProgress(0.2)
            
            do {
                guard let jsonData = jsonString.data(using: .utf8) else {
                    showErrorToast("Import Failed", message: "Invalid JSON format")
                    return false
                }
                updateProgress(0.4)
                
                let importData = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
                guard let tierData = importData?["tiers"] as? [String: [[String: String]]] else {
                    showErrorToast("Import Failed", message: "Invalid tier data format")
                    return false
                }
                updateProgress(0.6)
                
                var newTiers: TLTiers = [:]
                
                for (tierName, contestantData) in tierData {
                    newTiers[tierName] = contestantData.compactMap { data in
                        guard let id = data["id"], !id.isEmpty else { return nil }
                        return TLContestant(
                            id: id,
                            name: data["name"]?.isEmpty == false ? data["name"] : nil,
                            season: data["season"]?.isEmpty == false ? data["season"] : nil,
                            thumbUri: nil
                        )
                    }
                }
                updateProgress(0.8)
                
                await MainActor.run {
                    tiers = newTiers
                    history = TLHistoryLogic.initHistory(tiers, limit: history.limit)
                    markAsChanged()
                }
                updateProgress(1.0)
                
                showSuccessToast("Import Complete", message: "Successfully imported tier list")
                return true
            } catch {
                showErrorToast("Import Failed", message: "Could not parse JSON data")
                return false
            }
        }
    }
    
    func importFromCSV(_ csvString: String) async -> Bool {
        return await withLoadingIndicator(message: "Importing CSV data...") {
            updateProgress(0.2)
            
            let lines = csvString.components(separatedBy: .newlines)
            guard lines.count > 1 else {
                showErrorToast("Import Failed", message: "CSV file appears to be empty")
                return false
            }
            updateProgress(0.4)
            
            var newTiers: TLTiers = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
            
            // Skip header row
            for line in lines.dropFirst() {
                guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                
                let components = parseCSVLine(line)
                guard components.count >= 3 else { continue }
                
                let name = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let season = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let tier = components[2].trimmingCharacters(in: .whitespacesAndNewlines)
                
                guard !name.isEmpty else { continue }
                
                let contestant = TLContestant(
                    id: name.lowercased().replacingOccurrences(of: " ", with: "_"),
                    name: name,
                    season: season.isEmpty ? nil : season,
                    thumbUri: nil
                )
                
                let tierKey = tier.lowercased() == "unranked" ? "unranked" : tier.uppercased()
                if newTiers[tierKey] != nil {
                    newTiers[tierKey]?.append(contestant)
                } else {
                    newTiers["unranked"]?.append(contestant)
                }
            }
            updateProgress(0.8)
            
            await MainActor.run {
                tiers = newTiers
                history = TLHistoryLogic.initHistory(tiers, limit: history.limit)
                markAsChanged()
            }
            updateProgress(1.0)
            
            showSuccessToast("Import Complete", message: "Successfully imported CSV data")
            return true
        }
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        var components: [String] = []
        var currentComponent = ""
        var insideQuotes = false
        
        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                components.append(currentComponent)
                currentComponent = ""
            } else {
                currentComponent.append(char)
            }
        }
        components.append(currentComponent)
        
        return components.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") }
    }
    
    // URL-based import methods for file handling
    func importFromJSON(url: URL) async -> Bool {
        // Try to load as a full project JSON (new schema) and resolve tiers/items
        do {
            let dict = try ModelResolver.loadProject(from: url)
            let resolved = ModelResolver.resolveTiers(from: dict)
            var newTiers: TLTiers = [:]
            var newOrder: [String] = []
            for rt in resolved {
                newOrder.append(rt.label)
                newTiers[rt.label] = rt.items.map { ri in
                    TLContestant(id: ri.id, name: ri.title, season: nil, thumbUri: ri.thumbUri)
                }
            }
            await MainActor.run {
                self.tierOrder = newOrder
                self.tiers = newTiers
                self.history = TLHistoryLogic.initHistory(self.tiers, limit: self.history.limit)
                self.markAsChanged()
            }
            showSuccessToast("Import Complete", message: "Project loaded successfully")
            return true
        } catch {
            // Fallback to previous simple JSON import
            do {
                let data = try Data(contentsOf: url)
                let content = String(data: data, encoding: .utf8) ?? ""
                return await importFromJSON(content)
            } catch {
                showErrorToast("Import Failed", message: "Could not read JSON file: \(error.localizedDescription)")
                return false
            }
        }
    }
    
    func importFromCSV(url: URL) async -> Bool {
        do {
            let data = try Data(contentsOf: url)
            let content = String(data: data, encoding: .utf8) ?? ""
            return await importFromCSV(content)
        } catch {
            showErrorToast("Import Failed", message: "Could not read CSV file: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Analysis & Statistics System
    
    @Published var showingAnalysis = false
    @Published var analysisData: TierAnalysisData?
    
    func generateAnalysis() async {
        analysisData = await withLoadingIndicator(message: "Generating analysis...") {
            updateProgress(0.1)
            
            let totalContestants = tiers.values.flatMap { $0 }.count
            guard totalContestants > 0 else {
                updateProgress(1.0)
                return TierAnalysisData.empty
            }
            
            updateProgress(0.3)
            
            // Calculate tier distribution
            let tierDistribution = tierOrder.compactMap { tier in
                let count = tiers[tier]?.count ?? 0
                let percentage = totalContestants > 0 ? Double(count) / Double(totalContestants) * 100 : 0
                return TierDistributionData(tier: tier, count: count, percentage: percentage)
            }
            
            updateProgress(0.5)
            
            // Find tier with most/least contestants
            let mostPopulatedTier = tierDistribution.max(by: { $0.count < $1.count })
            let leastPopulatedTier = tierDistribution.min(by: { $0.count < $1.count })
            
            updateProgress(0.7)
            
            // Calculate tier balance score (how evenly distributed)
            let idealPercentage = 100.0 / Double(tierOrder.count)
            let balanceScore = 100.0 - tierDistribution.reduce(0) { acc, tier in
                acc + abs(tier.percentage - idealPercentage)
            } / Double(tierOrder.count)
            
            updateProgress(0.9)
            
            // Generate insights
            var insights: [String] = []
            
            if let mostPopulated = mostPopulatedTier, mostPopulated.percentage > 40 {
                insights.append("Tier \(mostPopulated.tier) contains \(String(format: "%.1f", mostPopulated.percentage))% of all contestants")
            }
            
            if balanceScore < 50 {
                insights.append("Tiers are unevenly distributed - consider rebalancing")
            } else if balanceScore > 80 {
                insights.append("Tiers are well-balanced across all categories")
            }
            
            let unrankedCount = tiers["unranked"]?.count ?? 0
            if unrankedCount > 0 {
                let unrankedPercentage = Double(unrankedCount) / Double(totalContestants + unrankedCount) * 100
                insights.append("\(String(format: "%.1f", unrankedPercentage))% of contestants remain unranked")
            }
            
            updateProgress(1.0)
            
            return TierAnalysisData(
                totalContestants: totalContestants,
                tierDistribution: tierDistribution,
                mostPopulatedTier: mostPopulatedTier?.tier,
                leastPopulatedTier: leastPopulatedTier?.tier,
                balanceScore: balanceScore,
                insights: insights,
                unrankedCount: unrankedCount
            )
        }
    }
    
    func toggleAnalysis() {
        showingAnalysis.toggle()
        if showingAnalysis && analysisData == nil {
            Task {
                await generateAnalysis()
            }
        }
    }

    func exportText(group: String = "All", themeName: String = "Default") -> String {
        let cfg: TLTierConfig = [
            "S": (name: "S", description: nil),
            "A": (name: "A", description: nil),
            "B": (name: "B", description: nil),
            "C": (name: "C", description: nil),
            "D": (name: "D", description: nil),
            "F": (name: "F", description: nil)
        ]
        return TLExportFormatter.generate(group: group, date: .now, themeName: themeName, tiers: tiers, tierConfig: cfg)
    }

    // MARK: - Quick Rank
    func beginQuickRank(_ contestant: TLContestant) { quickRankTarget = contestant }
    func cancelQuickRank() { quickRankTarget = nil }
    func commitQuickRank(to tier: String) {
        guard let c = quickRankTarget else { return }
        let next = TLQuickRankLogic.assign(tiers, contestantId: c.id, to: tier)
        guard next != tiers else { quickRankTarget = nil; return }
        tiers = next
        history = TLHistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        quickRankTarget = nil
    }

    // MARK: - Head to Head
    func startH2H() {
        let pool = (tiers["unranked"] ?? []) + tierOrder.flatMap { tiers[$0] ?? [] }
        h2hPool = pool
        h2hRecords = [:]
        h2hActive = true
        nextH2HPair()
    }

    func nextH2HPair() {
        guard h2hActive else { return }
        if let pair = TLHeadToHeadLogic.pickPair(from: h2hPool, rng: { Double.random(in: 0...1) }) {
            h2hPair = (pair.0, pair.1)
        } else {
            h2hPair = nil
        }
    }

    func voteH2H(winner: TLContestant) {
        guard h2hActive, let pair = h2hPair else { return }
        let a = pair.0, b = pair.1
        TLHeadToHeadLogic.vote(a, b, winner: winner, records: &h2hRecords)
        nextH2HPair()
    }

    func finishH2H() {
        guard h2hActive else { return }
        // build ranking using current pool and records
        let ranking = TLHeadToHeadLogic.ranking(from: h2hPool, records: h2hRecords)
        let distributed = TLHeadToHeadLogic.distributeRoundRobin(ranking, into: tierOrder, baseTiers: tiers)
        tiers = distributed
        history = TLHistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        h2hActive = false
        h2hPair = nil
        h2hPool = []
        h2hRecords = [:]
    }
}
