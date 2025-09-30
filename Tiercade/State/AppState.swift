import Foundation
import SwiftUI
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
final class AppState: ObservableObject {
    @Published var tiers: Items = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
    @Published var tierOrder: [String] = ["S", "A", "B", "C", "D", "F"]
    @Published var searchQuery: String = ""
    @Published var activeFilter: FilterType = .all
    @Published var currentToast: ToastMessage?
    @Published var quickRankTarget: Item?
    // tvOS quick move (Play/Pause accelerator)
    @Published var quickMoveTarget: Item?
    // Multi-select state for batch operations
    @Published var selection: Set<String> = []
    @Published var isMultiSelect: Bool = false
    // Detail overlay routing
    @Published var detailItem: Item?
    // Item menu overlay routing (tvOS primary action)
    @Published var itemMenuTarget: Item?
    // Locked tiers set (until full Tier model exists)
    @Published var lockedTiers: Set<String> = []
    // Tier display overrides (rename/recolor without core model changes)
    @Published var tierLabels: [String: String] = [:] // tierId -> display label
    @Published var tierColors: [String: String] = [:] // tierId -> hex color
    // Head-to-Head
    @Published var h2hActive: Bool = false
    @Published var h2hPool: [Item] = []
    @Published var h2hPair: (Item, Item)?
    @Published var h2hRecords: [String: H2HRecord] = [:]

    // Enhanced Persistence
    @Published var hasUnsavedChanges: Bool = false
    @Published var lastSavedTime: Date?
    @Published var currentFileName: String?

    // Progress Tracking & Visual Feedback
    @Published var isLoading: Bool = false
    @Published var loadingMessage: String = ""
    @Published var operationProgress: Double = 0.0
    @Published var dragTargetTier: String?
    @Published var draggingId: String?
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

    // MARK: - Enhanced Persistence

    // MARK: - Async File Operations with Progress Tracking

    // Export/import helpers moved to AppState+ExportImport.swift

    // MARK: - Analysis & Statistics System

    @Published var showingAnalysis = false
    @Published var analysisData: TierAnalysisData?

    // MARK: - Accessibility
    func announce(_ message: String) {
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}
