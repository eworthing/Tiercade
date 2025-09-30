import Foundation
import SwiftUI
import Observation
#if canImport(UIKit)
import UIKit
#endif

import TiercadeCore

// Use core Item/Items and core logic directly (breaking change)

// MARK: - Export & Import System Types

enum ExportFormat: CaseIterable {
    case text, json, markdown, csv, png, pdf

    var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .json: return "json"
        case .markdown: return "md"
        case .csv: return "csv"
        case .png: return "png"
        case .pdf: return "pdf"
        }
    }

    var displayName: String {
        switch self {
        case .text: return "Plain Text"
        case .json: return "JSON"
        case .markdown: return "Markdown"
        case .csv: return "CSV"
        case .png: return "PNG Image"
        case .pdf: return "PDF"
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
@Observable
final class AppState {
    var tiers: Items = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
    var tierOrder: [String] = ["S", "A", "B", "C", "D", "F"]
    var searchQuery: String = ""
    var activeFilter: FilterType = .all
    var currentToast: ToastMessage?
    var quickRankTarget: Item?
    // tvOS quick move (Play/Pause accelerator)
    var quickMoveTarget: Item?
    // Multi-select state for batch operations
    var selection: Set<String> = []
    var isMultiSelect: Bool = false
    // Detail overlay routing
    var detailItem: Item?
    // Item menu overlay routing (tvOS primary action)
    var itemMenuTarget: Item?
    // Locked tiers set (until full Tier model exists)
    var lockedTiers: Set<String> = []
    // Tier display overrides (rename/recolor without core model changes)
    var tierLabels: [String: String] = [:] // tierId -> display label
    var tierColors: [String: String] = [:] // tierId -> hex color
    // Head-to-Head
    var h2hActive: Bool = false
    var h2hPool: [Item] = []
    var h2hPair: (Item, Item)?
    var h2hRecords: [String: H2HRecord] = [:]
    var h2hPairsQueue: [(Item, Item)] = []
    var h2hDeferredPairs: [(Item, Item)] = []
    var h2hTotalComparisons: Int = 0
    var h2hCompletedComparisons: Int = 0
    var h2hSkippedPairKeys: Set<String> = []

    // Enhanced Persistence
    var hasUnsavedChanges: Bool = false
    var lastSavedTime: Date?
    var currentFileName: String?

    // Progress Tracking & Visual Feedback
    var isLoading: Bool = false
    var loadingMessage: String = ""
    var operationProgress: Double = 0.0
    var dragTargetTier: String?
    var draggingId: String?
    var isProcessingSearch: Bool = false
    var showAnalyticsSidebar: Bool = false

    let storageKey = "Tiercade.tiers.v1"
    var autosaveTask: Task<Void, Never>?
    let autosaveInterval: TimeInterval = 30.0 // Auto-save every 30 seconds

    var history = History<Items>(stack: [], index: 0, limit: 80)

    var h2hProgress: Double {
        guard h2hTotalComparisons > 0 else { return 0 }
        return min(Double(h2hCompletedComparisons) / Double(h2hTotalComparisons), 1.0)
    }

    var h2hRemainingComparisons: Int {
        max(h2hTotalComparisons - h2hCompletedComparisons, 0)
    }

    var h2hSkippedCount: Int { h2hSkippedPairKeys.count }

    init() {
        if !load() {
            seed()
        }
        history = HistoryLogic.initHistory(tiers, limit: 80)
        setupAutosave()

        let tierSummary = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        let unrankedCount = tiers["unranked"]?.count ?? 0
        let initMsg = "init: tiers counts=\(tierSummary) unranked=\(unrankedCount)"
        logEvent(initMsg)
    }

    // Write a small debug file to /tmp to make logs visible from the host
    nonisolated func appendDebugFile(_ message: String) {
        DispatchQueue.global(qos: .utility).async {
            let path = "/tmp/tiercade_debug.log"
            let ts = ISO8601DateFormatter().string(from: Date())
            let pid = ProcessInfo.processInfo.processIdentifier
            let line = "\(ts) [pid:\(pid)] \(message)\n"
            if !FileManager.default.fileExists(atPath: path) {
                let attributes: [FileAttributeKey: Any] = [
                    .posixPermissions: 0o644
                ]
                FileManager.default.createFile(
                    atPath: path,
                    contents: Data(line.utf8),
                    attributes: attributes
                )
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
                    let attributes: [FileAttributeKey: Any] = [
                        .posixPermissions: 0o644
                    ]
                    FileManager.default.createFile(
                        atPath: docPath.path,
                        contents: Data(line.utf8),
                        attributes: attributes
                    )
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

    private func setupAutosave() {
        autosaveTask?.cancel()
        let interval = autosaveInterval
        autosaveTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: .seconds(interval))
                } catch {
                    return
                }

                guard let self else { return }
                await self.performAutosaveIfNeeded()
            }
        }
    }

    @MainActor
    private func performAutosaveIfNeeded() {
        if hasUnsavedChanges {
            try? autoSave()
        }
    }

    func markAsChanged() {
        hasUnsavedChanges = true
    }

    func logEvent(_ message: String) {
        let formatted = "[AppState] \(message)"
        print(formatted)
        NSLog("%@", formatted)
        appendDebugFile(formatted)
    }

    func seed() {
        tiers["unranked"] = [
            Item(id: "kyle48", name: "Kyle Fraser", seasonString: "48"),
            Item(id: "parvati", name: "Parvati Shallow", seasonString: "Multiple"),
            Item(id: "sandra", name: "Sandra Diaz-Twine", seasonString: "Multiple")
        ]
    }

    func undo() {
        guard HistoryLogic.canUndo(history) else { return }
        history = HistoryLogic.undo(history)
        tiers = HistoryLogic.current(history)
        markAsChanged()
        showInfoToast("Undone", message: "Last action has been undone")
        let counts = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        logEvent("undo: canUndo=\(HistoryLogic.canUndo(history)) counts=\(counts)")
    }

    func redo() {
        guard HistoryLogic.canRedo(history) else { return }
        history = HistoryLogic.redo(history)
        tiers = HistoryLogic.current(history)
        markAsChanged()
        showInfoToast("Redone", message: "Action has been redone")
        let counts = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        logEvent("redo: canRedo=\(HistoryLogic.canRedo(history)) counts=\(counts)")
    }
    var canUndo: Bool { HistoryLogic.canUndo(history) }
    var canRedo: Bool { HistoryLogic.canRedo(history) }
    var totalItemCount: Int {
        tiers.values.reduce(into: 0) { partialResult, items in
            partialResult += items.count
        }
    }
    var hasAnyItems: Bool { totalItemCount > 0 }
    var hasEnoughForPairing: Bool { totalItemCount >= 2 }
    var canRandomizeItems: Bool { totalItemCount > 1 }
    var canStartHeadToHead: Bool { !h2hActive && hasEnoughForPairing }
    var canShowAnalysis: Bool { hasAnyItems }

    // MARK: - Enhanced Persistence

    // MARK: - Async File Operations with Progress Tracking

    // Export/import helpers moved to AppState+ExportImport.swift

    // MARK: - Analysis & Statistics System

    var showingAnalysis = false
    var analysisData: TierAnalysisData?

    // MARK: - Accessibility
    func announce(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}
