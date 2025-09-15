import Foundation
import SwiftUI

// Ensure SharedCore types are accessible
// TL* types defined in SharedCore.swift should be available in same module

@MainActor
final class AppState: ObservableObject {
    @Published var tiers: TLTiers = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
    @Published var tierOrder: [String] = ["S","A","B","C","D","F"]
    @Published var searchQuery: String = ""
    @Published var toast: String? = nil
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
    
    private let storageKey = "Tiercade.tiers.v1"
    private var autosaveTimer: Timer?
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
            TLContestant(id: "kyle48", name: "Kyle Fraser", season: "48"),
            TLContestant(id: "parvati", name: "Parvati Shallow", season: "Multiple"),
            TLContestant(id: "sandra", name: "Sandra Diaz-Twine", season: "Multiple")
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
    }

    func undo() { 
        guard TLHistoryLogic.canUndo(history) else { return }
        history = TLHistoryLogic.undo(history)
        tiers = TLHistoryLogic.current(history)
        markAsChanged()
    }
    
    func redo() { 
        guard TLHistoryLogic.canRedo(history) else { return }
        history = TLHistoryLogic.redo(history)
        tiers = TLHistoryLogic.current(history)
        markAsChanged()
    }
    var canUndo: Bool { TLHistoryLogic.canUndo(history) }
    var canRedo: Bool { TLHistoryLogic.canRedo(history) }

    func reset() {
        tiers = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
        seed()
        history = TLHistoryLogic.initHistory(tiers, limit: history.limit)
        markAsChanged()
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
    }

    // MARK: - Enhanced Persistence
    
    @discardableResult
    func save() -> Bool {
        do {
            let data = try JSONEncoder().encode(tiers)
            UserDefaults.standard.set(data, forKey: storageKey)
            hasUnsavedChanges = false
            lastSavedTime = Date()
            return true
        } catch {
            print("Save failed: \(error)")
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
            
            return true
        } catch {
            print("File save failed: \(error)")
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
            return true
        } catch {
            print("Load failed: \(error)")
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
            
            return true
        } catch {
            print("File load failed: \(error)")
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
