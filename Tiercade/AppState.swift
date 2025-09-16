import Foundation
import SwiftUI

import TiercadeCore

// Use core Item/Items and core logic directly (breaking change)

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
    let totalItems: Int
    let tierDistribution: [TierDistributionData]
    let mostPopulatedTier: String?
    let leastPopulatedTier: String?
    let balanceScore: Double
    let insights: [String]
    let unrankedCount: Int
    
    static let empty = TierAnalysisData(
        totalItems: 0,
        tierDistribution: [],
        mostPopulatedTier: nil,
        leastPopulatedTier: nil,
        balanceScore: 0,
    insights: ["No items found - add some items to see analysis"],
        unrankedCount: 0
    )
}

@MainActor
final class AppState: ObservableObject {
    @Published var tiers: Items = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
    @Published var tierOrder: [String] = ["S","A","B","C","D","F"]
    @Published var searchQuery: String = ""
    @Published var activeFilter: FilterType = .all
    @Published var currentToast: ToastMessage? = nil
    @Published var quickRankTarget: Item? = nil
    // Head-to-Head
    @Published var h2hActive: Bool = false
    @Published var h2hPool: [Item] = []
    @Published var h2hPair: (Item, Item)? = nil
    @Published var h2hRecords: [String: H2HRecord] = [:]
    
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
    
    let storageKey = "Tiercade.tiers.v1"
    nonisolated(unsafe) var autosaveTimer: Timer?
    let autosaveInterval: TimeInterval = 30.0 // Auto-save every 30 seconds

    var history = History<Items>(stack: [], index: 0, limit: 80)

    init() {
        if !load() {
            seed()
        }
    history = HistoryLogic.initHistory(tiers, limit: 80)
        setupAutosave()
        let initMsg = "[AppState] init: tiers counts=\(tierOrder.map { "\($0):\(tiers[$0]?.count ?? 0)" }.joined(separator: ", ")) unranked=\(tiers["unranked"]?.count ?? 0)"
        print(initMsg)
        NSLog("%@", initMsg)
        appendDebugFile(initMsg)
    }

    // Write a small debug file to /tmp to make logs visible from the host
    nonisolated func appendDebugFile(_ message: String) {
        DispatchQueue.global(qos: .utility).async {
            let path = "/tmp/tiercade_debug.log"
            let ts = ISO8601DateFormatter().string(from: Date())
            let pid = ProcessInfo.processInfo.processIdentifier
            let line = "\(ts) [pid:\(pid)] \(message)\n"
            if !FileManager.default.fileExists(atPath: path) {
                FileManager.default.createFile(atPath: path, contents: Data(line.utf8), attributes: [FileAttributeKey.posixPermissions: 0o644])
            } else {
                if let fh = try? FileHandle(forWritingTo: URL(fileURLWithPath: path)) {
                    do {
                        try fh.seekToEnd()
                        try fh.write(contentsOf: Data(line.utf8))
                        try fh.close()
                    } catch {
                        // ignore
                    }
                }
            }
            // Also write to Documents so host tools can easily retrieve the file
            if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let docPath = docs.appendingPathComponent("tiercade_debug.log")
                if !FileManager.default.fileExists(atPath: docPath.path) {
                    FileManager.default.createFile(atPath: docPath.path, contents: Data(line.utf8), attributes: [FileAttributeKey.posixPermissions: 0o644])
                } else {
                    if let fh = try? FileHandle(forWritingTo: docPath) {
                        do {
                            try fh.seekToEnd()
                            try fh.write(contentsOf: Data(line.utf8))
                            try fh.close()
                        } catch {
                            // ignore
                        }
                    }
                }
            }
        }
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
    
    func markAsChanged() {
        hasUnsavedChanges = true
    }

    func seed() {
        tiers["unranked"] = [
            Item(id: "kyle48", name: "Kyle Fraser", seasonString: "48"),
            Item(id: "parvati", name: "Parvati Shallow", seasonString: "Multiple"),
            Item(id: "sandra", name: "Sandra Diaz-Twine", seasonString: "Multiple")
        ]
    }

    func move(_ id: String, to tier: String) {
    let next = TierLogic.moveItem(tiers, itemId: id, targetTierName: tier)
        guard next != tiers else { return }
        tiers = next
    history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
    print("[AppState] move: itemId=\(id) -> tier=\(tier)\n    counts: \(tierOrder.map { (name) in "\(name):\(tiers[name]?.count ?? 0)" }.joined(separator: ", "))")
    NSLog("[AppState] move: itemId=%@ -> tier=%@ counts=%@", id, tier, tierOrder.map { "\($0):\(tiers[$0]?.count ?? 0)" }.joined(separator: ", "))
    }

    func clearTier(_ tier: String) {
        var next = tiers
        guard let moving = next[tier], !moving.isEmpty else { return }
        next[tier] = []
        next["unranked", default: []].append(contentsOf: moving)
        tiers = next
    history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
    showInfoToast("Tier Cleared", message: "Moved all items from \(tier) tier to unranked")
    }

    func undo() { 
    guard HistoryLogic.canUndo(history) else { return }
    history = HistoryLogic.undo(history)
    tiers = HistoryLogic.current(history)
        markAsChanged()
        showInfoToast("Undone", message: "Last action has been undone")
    print("[AppState] undo: canUndo=\(HistoryLogic.canUndo(history)) now tiers snapshot saved; counts: \(tierOrder.map { "\($0):\(tiers[$0]?.count ?? 0)" }.joined(separator: ", "))")
    NSLog("[AppState] undo: canUndo=%d counts=%@", HistoryLogic.canUndo(history) ? 1 : 0, tierOrder.map { "\($0):\(tiers[$0]?.count ?? 0)" }.joined(separator: ", "))
    }
    
    func redo() { 
    guard HistoryLogic.canRedo(history) else { return }
    history = HistoryLogic.redo(history)
    tiers = HistoryLogic.current(history)
        markAsChanged()
        showInfoToast("Redone", message: "Action has been redone")
    print("[AppState] redo: canRedo=\(HistoryLogic.canRedo(history)) now tiers snapshot saved; counts: \(tierOrder.map { "\($0):\(tiers[$0]?.count ?? 0)" }.joined(separator: ", "))")
    NSLog("[AppState] redo: canRedo=%d counts=%@", HistoryLogic.canRedo(history) ? 1 : 0, tierOrder.map { "\($0):\(tiers[$0]?.count ?? 0)" }.joined(separator: ", "))
    }
    var canUndo: Bool { HistoryLogic.canUndo(history) }
    var canRedo: Bool { HistoryLogic.canRedo(history) }
    
    // MARK: - Search & Filter
    func filteredItems(for tier: String) -> [Item] {
        let items = tiers[tier] ?? []
        return applySearchFilter(to: items)
    }

    func allItems() -> [Item] {
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

    // Convenience count helpers to centralize tier counting logic
    func tierCount(_ tier: String) -> Int { tiers[tier]?.count ?? 0 }
    func rankedCount() -> Int { tierOrder.flatMap { tiers[$0] ?? [] }.count }
    func unrankedCount() -> Int { tiers["unranked"]?.count ?? 0 }
    func items(for tier: String) -> [Item] { tiers[tier] ?? [] }
    
    func applySearchFilter(to items: [Item]) -> [Item] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return items }

        // Show processing indicator for large datasets
        if items.count > 50 {
            setSearchProcessing(true)
        }

        let filteredResults = items.filter { item in
            let name = (item.name ?? "").lowercased()
            let season = (item.seasonString ?? "").lowercased()
            let id = item.id.lowercased()

            return name.contains(query) || season.contains(query) || id.contains(query)
        }

        if items.count > 50 {
            setSearchProcessing(false)
        }

        return filteredResults
    }
    
    // Toast helpers moved to AppState+Toast.swift

    func reset() {
        tiers = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
        seed()
        history = HistoryLogic.initHistory(tiers, limit: history.limit)
        markAsChanged()
    }

    // MARK: - Add Item
    func addItem(id: String, attributes: [String: String]? = nil) {
        let c = Item(id: id, attributes: attributes)
        var next = tiers
        next["unranked", default: []].append(c)
        tiers = next
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        let display = attributes?[("name")] ?? id
        showSuccessToast("Added", message: "Added \(display) to Unranked")
    }
    
    func randomize() {
        // Collect all items from all tiers
        var allItems: [Item] = []
        for tierName in tierOrder + ["unranked"] {
            allItems.append(contentsOf: tiers[tierName] ?? [])
        }

        // Clear all tiers
        var newTiers = tiers
        for tierName in tierOrder + ["unranked"] {
            newTiers[tierName] = []
        }

        // Shuffle and redistribute
        allItems.shuffle()
        let tiersToFill = tierOrder // Don't include unranked in randomization
        let itemsPerTier = max(1, allItems.count / tiersToFill.count)

        for (index, item) in allItems.enumerated() {
            let tierIndex = min(index / itemsPerTier, tiersToFill.count - 1)
            let tierName = tiersToFill[tierIndex]
            newTiers[tierName, default: []].append(item)
        }

        tiers = newTiers
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()

        showSuccessToast("Tiers Randomized", message: "All items have been redistributed randomly")
    }

    // MARK: - Progress Tracking & Visual Feedback
    
    func setLoading(_ loading: Bool, message: String = "") {
        isLoading = loading
        loadingMessage = message
        if loading {
            operationProgress = 0.0
        }
    print("[AppState] setLoading: loading=\(loading) message=\(message) progress=\(operationProgress)")
    NSLog("[AppState] setLoading: loading=%d message=%@ progress=%f", loading ? 1 : 0, message, operationProgress)
    }
    
    func updateProgress(_ progress: Double) {
        operationProgress = min(max(progress, 0.0), 1.0)
    }
    
    func setDragTarget(_ tierName: String?) {
        dragTargetTier = tierName
    print("[AppState] setDragTarget: \(tierName ?? "nil")")
    NSLog("[AppState] setDragTarget: %@", tierName ?? "nil")
    }

    func setDragging(_ id: String?) {
        draggingId = id
    print("[AppState] setDragging: \(id ?? "nil")")
    NSLog("[AppState] setDragging: %@", id ?? "nil")
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
    
    

    
    
    
    
    
    
    
    
    // MARK: - Async File Operations with Progress Tracking
    
    
    
    

    // Export/import helpers moved to AppState+ExportImport.swift
    
    // MARK: - Analysis & Statistics System
    
    @Published var showingAnalysis = false
    @Published var analysisData: TierAnalysisData?
    
    func generateAnalysis() async {
        analysisData = await withLoadingIndicator(message: "Generating analysis...") {
            updateProgress(0.1)
            
            let totalItems = tiers.values.flatMap { $0 }.count
            guard totalItems > 0 else {
                updateProgress(1.0)
                return TierAnalysisData.empty
            }
            
            updateProgress(0.3)
            
            // Calculate tier distribution
            let tierDistribution = tierOrder.compactMap { tier in
                let count = tiers[tier]?.count ?? 0
                let percentage = totalItems > 0 ? Double(count) / Double(totalItems) * 100 : 0
                return TierDistributionData(tier: tier, count: count, percentage: percentage)
            }
            
            updateProgress(0.5)
            
            // Find tier with most/least items
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
                insights.append("Tier \(mostPopulated.tier) contains \(String(format: "%.1f", mostPopulated.percentage))% of all items")
            }
            
            if balanceScore < 50 {
                insights.append("Tiers are unevenly distributed - consider rebalancing")
            } else if balanceScore > 80 {
                insights.append("Tiers are well-balanced across all categories")
            }
            
            let unrankedCount = tiers["unranked"]?.count ?? 0
            if unrankedCount > 0 {
                let unrankedPercentage = Double(unrankedCount) / Double(totalItems + unrankedCount) * 100
                insights.append("\(String(format: "%.1f", unrankedPercentage))% of items remain unranked")
            }
            
            updateProgress(1.0)
            
            return TierAnalysisData(
                totalItems: totalItems,
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

    // exportText moved to AppState+ExportImport.swift

    // MARK: - Quick Rank
    func beginQuickRank(_ item: Item) { quickRankTarget = item }
    func cancelQuickRank() { quickRankTarget = nil }
    func commitQuickRank(to tier: String) {
        guard let i = quickRankTarget else { return }
        let next = QuickRankLogic.assign(tiers, itemId: i.id, to: tier)
        guard next != tiers else { quickRankTarget = nil; return }
        tiers = next
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        quickRankTarget = nil
    print("[AppState] commitQuickRank: item=\(i.id) -> tier=\(tier)")
    NSLog("[AppState] commitQuickRank: item=%@ -> tier=%@", i.id, tier)
        appendDebugFile("commitQuickRank: item=\(i.id) -> tier=\(tier)")
    }

    // MARK: - Head to Head
    func startH2H() {
        let pool = (tiers["unranked"] ?? []) + tierOrder.flatMap { tiers[$0] ?? [] }
        h2hPool = pool
        h2hRecords = [:]
        h2hActive = true
    print("[AppState] startH2H: poolCount=\(h2hPool.count)")
    NSLog("[AppState] startH2H: poolCount=%d", h2hPool.count)
        appendDebugFile("startH2H: poolCount=\(h2hPool.count)")
        nextH2HPair()
    }

    func nextH2HPair() {
        guard h2hActive else { return }
        if let pair = HeadToHeadLogic.pickPair(from: h2hPool, rng: { Double.random(in: 0...1) }) {
            h2hPair = (pair.0, pair.1)
            print("[AppState] nextH2HPair: pair=\(pair.0.id) vs \(pair.1.id)")
            NSLog("[AppState] nextH2HPair: pair=%@ vs %@", pair.0.id, pair.1.id)
        } else {
            h2hPair = nil
            print("[AppState] nextH2HPair: no pair available (ending H2H?)")
            NSLog("[AppState] nextH2HPair: no pair available")
        }
    }

    func voteH2H(winner: Item) {
        guard h2hActive, let pair = h2hPair else { return }
        let a = pair.0, b = pair.1
        HeadToHeadLogic.vote(a, b, winner: winner, records: &h2hRecords)
        nextH2HPair()
    print("[AppState] voteH2H: winner=\(winner.id) pair=\(a.id)-\(b.id) remainingPool=\(h2hPool.count) records=\(h2hRecords.count)")
    NSLog("[AppState] voteH2H: winner=%@ pair=%@-%@ remainingPool=%d records=%d", winner.id, a.id, b.id, h2hPool.count, h2hRecords.count)
    }

    func finishH2H() {
        guard h2hActive else { return }
        // build ranking using current pool and records
        let ranking = HeadToHeadLogic.ranking(from: h2hPool, records: h2hRecords)
        let distributed = HeadToHeadLogic.distributeRoundRobin(ranking, into: tierOrder, baseTiers: tiers)
        tiers = distributed
        history = HistoryLogic.saveSnapshot(history, snapshot: tiers)
        markAsChanged()
        h2hActive = false
        h2hPair = nil
        h2hPool = []
        h2hRecords = [:]
    print("[AppState] finishH2H: finished and distributed; counts: \(tierOrder.map { "\($0):\(tiers[$0]?.count ?? 0)" }.joined(separator: ", "))")
    NSLog("[AppState] finishH2H: counts=%@", tierOrder.map { "\($0):\(tiers[$0]?.count ?? 0)" }.joined(separator: ", "))
        appendDebugFile("finishH2H: counts=\(tierOrder.map { "\($0):\(tiers[$0]?.count ?? 0)" }.joined(separator: ", "))")
    }

    // MARK: - Data Normalization / Migration Helpers

    /// Ensure every item has an attributes bag; migrate legacy top-level fields into attributes.
    static func normalizedTiers(from tiers: Items) -> Items {
        var out: Items = [:]
        for (k, v) in tiers {
            out[k] = v.map { c in
                // Build a normalized Item that uses canonical properties. If the
                // item already contains name/season/image fields, keep them.
                return Item(id: c.id,
                            name: c.name,
                            seasonString: c.seasonString,
                            seasonNumber: c.seasonNumber,
                            status: c.status,
                            description: c.description,
                            imageUrl: c.imageUrl,
                            videoUrl: c.videoUrl)
            }
        }
        return out
    }
}
