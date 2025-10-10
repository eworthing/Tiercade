import Foundation
import SwiftUI
import Observation
import SwiftData
import Accessibility
import os

import TiercadeCore

// Use core Item/Items and core logic directly (breaking change)

// MARK: - Export & Import System Types

nonisolated enum ExportFormat: CaseIterable {
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
    struct TierStateSnapshot: Sendable {
        var tiers: Items
        var tierOrder: [String]
        var tierLabels: [String: String]
        var tierColors: [String: String]
        var lockedTiers: Set<String>
    }

    let modelContext: ModelContext
    var tiers: Items = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
    var tierOrder: [String] = ["S", "A", "B", "C", "D", "F"]
    var searchQuery: String = ""
    var activeFilter: FilterType = .all
    var currentToast: ToastMessage?
    var quickRankTarget: Item?
    // tvOS quick move (Play/Pause accelerator)
    var quickMoveTarget: Item?
    var batchQuickMoveActive: Bool = false
    // Multi-select state for batch operations (driven by editMode environment)
    var selection: Set<String> = []
    // Detail overlay routing
    var detailItem: Item?
    // Locked tiers set (until full Tier model exists)
    var lockedTiers: Set<String> = []
    // Tier display overrides (rename/recolor without core model changes)
    var tierLabels: [String: String] = [:] // tierId -> display label
    var tierColors: [String: String] = [:] // tierId -> hex color
    // Layout preferences
    var cardDensityPreference: CardDensityPreference = .compact
    // Theme selection
    var selectedThemeID: UUID = TierThemeCatalog.defaultTheme.id
    var selectedTheme: TierTheme = TierThemeCatalog.defaultTheme
    var showThemePicker: Bool = false
    var themePickerActive: Bool = false
    var customThemes: [TierTheme] = []
    var customThemeIDs: Set<UUID> = []
    var showThemeCreator: Bool = false
    var themeCreatorActive: Bool = false
    var themeDraft: ThemeDraft?
    // Head-to-Head
    var h2hActive: Bool = false
    enum H2HSessionPhase: Sendable {
        case quick
        case refinement
    }

    var h2hPool: [Item] = []
    var h2hPair: (Item, Item)?
    var h2hRecords: [String: H2HRecord] = [:]
    var h2hPairsQueue: [(Item, Item)] = []
    var h2hDeferredPairs: [(Item, Item)] = []
    var h2hTotalComparisons: Int = 0
    var h2hCompletedComparisons: Int = 0
    var h2hSkippedPairKeys: Set<String> = []
    var h2hActivatedAt: Date?
    var h2hPhase: H2HSessionPhase = .quick
    var h2hArtifacts: H2HArtifacts?
    var h2hSuggestedPairs: [(Item, Item)] = []
    var h2hInitialSnapshot: TierStateSnapshot?
    var h2hRefinementTotalComparisons: Int = 0
    var h2hRefinementCompletedComparisons: Int = 0

    // Enhanced Persistence
    var hasUnsavedChanges: Bool = false
    var lastSavedTime: Date?
    var currentFileName: String?
    var tierCreatorValidationIssues: [TierCreatorValidationIssue] = []
    var showingTierCreator: Bool = false
    var tierCreatorActiveProject: TierCreatorProject?
    var tierCreatorStage: TierCreatorStage = .setup
    var tierCreatorSelectedTierId: String?
    var tierCreatorSelectedItemId: String?
    var tierCreatorSearchQuery: String = ""

    // Progress Tracking & Visual Feedback
    var isLoading: Bool = false
    var loadingMessage: String = ""
    var operationProgress: Double = 0.0
    var dragTargetTier: String?
    var draggingId: String?
    var isProcessingSearch: Bool = false
    var showAnalyticsSidebar: Bool = false
    var showingTierListBrowser: Bool = false
    let bundledProjects: [BundledProject] = BundledProjects.all
    var activeTierList: TierListHandle?
    var recentTierLists: [TierListHandle] = []
    let maxRecentTierLists: Int = 6
    let quickPickMenuLimit: Int = 5

    // Confirmation alerts
    var showRandomizeConfirmation: Bool = false
    var showResetConfirmation: Bool = false

    let tierListStateKey = "Tiercade.tierlist.active.v1"
    let tierListRecentsKey = "Tiercade.tierlist.recents.v1"
    var autosaveTask: Task<Void, Never>?
    let autosaveInterval: TimeInterval = 30.0 // Auto-save every 30 seconds

    var undoManager: UndoManager?
    private var isPerformingUndoRedo = false

    var h2hProgress: Double {
        guard h2hTotalComparisons > 0 else { return 0 }
        return min(Double(h2hCompletedComparisons) / Double(h2hTotalComparisons), 1.0)
    }

    var h2hRemainingComparisons: Int {
        max(h2hTotalComparisons - h2hCompletedComparisons, 0)
    }

    var h2hRefinementProgress: Double {
        guard h2hRefinementTotalComparisons > 0 else { return 0 }
        return min(
            Double(h2hRefinementCompletedComparisons) / Double(h2hRefinementTotalComparisons),
            1.0
        )
    }

    var h2hRefinementRemainingComparisons: Int {
        max(h2hRefinementTotalComparisons - h2hRefinementCompletedComparisons, 0)
    }

    var h2hTotalDecidedComparisons: Int {
        h2hCompletedComparisons + h2hRefinementCompletedComparisons
    }

    var h2hTotalRemainingComparisons: Int {
        h2hRemainingComparisons + h2hRefinementRemainingComparisons
    }

    var h2hOverallProgress: Double {
        let quickWeight = 0.75
        var progress: Double = 0

        if h2hTotalComparisons > 0 {
            let quickFraction = Double(min(h2hCompletedComparisons, h2hTotalComparisons)) / Double(h2hTotalComparisons)
            progress = min(max(quickFraction, 0), 1) * quickWeight
        }

        if h2hRefinementTotalComparisons > 0 {
            let refinementFraction = Double(
                min(h2hRefinementCompletedComparisons, h2hRefinementTotalComparisons)
            ) / Double(h2hRefinementTotalComparisons)
            progress = min(progress, quickWeight)
            progress += (1 - quickWeight) * min(max(refinementFraction, 0), 1)
        } else if !h2hActive && h2hTotalComparisons > 0 && h2hCompletedComparisons >= h2hTotalComparisons {
            progress = 1.0
        }

        return min(max(progress, 0), 1)
    }

    var h2hSkippedCount: Int { h2hSkippedPairKeys.count }

    var activeTierListEntity: TierListEntity?

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        let didLoad = load()
        if !didLoad {
            seed()
        } else if isLegacyBundledListPlaceholder(tiers) {
            logEvent("init: detected legacy bundled list placeholder; reseeding default project")
            let defaults = UserDefaults.standard
            defaults.removeObject(forKey: tierListStateKey)
            defaults.removeObject(forKey: tierListRecentsKey)
            seed()
        }
        setupAutosave()

        let tierSummary = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        let unrankedCount = tiers["unranked"]?.count ?? 0
        let initMsg = "init: tiers counts=\(tierSummary) unranked=\(unrankedCount)"
        logEvent(initMsg)
        restoreTierListState()
        if !didLoad {
            loadActiveTierListIfNeeded()
        }
        prefillBundledProjectsIfNeeded()
    }

    // MARK: - Logging
    // Logging now uses Swift's unified logging system (os.Logger)
    // See Util/Logging.swift for logger definitions
    // Logs are viewable in Console.app and automatically integrated with system logging

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
    private func performAutosaveIfNeeded() async {
        if hasUnsavedChanges {
            await autoSaveAsync()
        }
    }

    func updateUndoManager(_ manager: UndoManager?) {
        undoManager = manager
    }

    func captureTierSnapshot() -> TierStateSnapshot {
        TierStateSnapshot(
            tiers: tiers,
            tierOrder: tierOrder,
            tierLabels: tierLabels,
            tierColors: tierColors,
            lockedTiers: lockedTiers
        )
    }

    func restore(from snapshot: TierStateSnapshot) {
        tiers = snapshot.tiers
        tierOrder = snapshot.tierOrder
        tierLabels = snapshot.tierLabels
        tierColors = snapshot.tierColors
        lockedTiers = snapshot.lockedTiers
    }

    func finalizeChange(action: String, undoSnapshot: TierStateSnapshot) {
        if !isPerformingUndoRedo {
            let redoSnapshot = captureTierSnapshot()
            registerUndo(action: action, undoSnapshot: undoSnapshot, redoSnapshot: redoSnapshot, isRedo: false)
        }
        markAsChanged()
    }

    private func registerUndo(
        action: String,
        undoSnapshot: TierStateSnapshot,
        redoSnapshot: TierStateSnapshot,
        isRedo: Bool
    ) {
        guard let manager = undoManager else { return }
        manager.registerUndo(withTarget: self) { target in
            target.performUndo(
                action: action,
                undoSnapshot: undoSnapshot,
                redoSnapshot: redoSnapshot,
                isRedo: isRedo
            )
        }
        manager.setActionName(action)
    }

    private func performUndo(
        action: String,
        undoSnapshot: TierStateSnapshot,
        redoSnapshot: TierStateSnapshot,
        isRedo: Bool
    ) {
        isPerformingUndoRedo = true
        defer { isPerformingUndoRedo = false }
        let inverseSnapshot = captureTierSnapshot()
        restore(from: undoSnapshot)
        markAsChanged()
        let toastTitle = isRedo ? "Redone" : "Undone"
        let toastMessage = isRedo ? "\(action) repeated {redo}" : "\(action) reverted {undo}"
        showInfoToast(toastTitle, message: toastMessage)
        undoManager?.registerUndo(withTarget: self) { target in
            target.performUndo(
                action: action,
                undoSnapshot: redoSnapshot,
                redoSnapshot: inverseSnapshot,
                isRedo: !isRedo
            )
        }
        undoManager?.setActionName(action)
    }

    func markAsChanged() {
        hasUnsavedChanges = true
    }

    /// Log a general app state event using unified logging
    func logEvent(_ message: String) {
        Logger.appState.info("\(message)")
    }

    func seed() {
        // Load the first bundled project as default instead of placeholder items
        guard let defaultProject = bundledProjects.first else {
            // Fallback to empty state if no bundled projects available
            tiers["unranked"] = []
            return
        }
        applyBundledProject(defaultProject)
        let fallbackTheme = TierThemeCatalog.defaultTheme
        selectedTheme = fallbackTheme
        selectedThemeID = fallbackTheme.id
        applyCurrentTheme()
        cardDensityPreference = .compact
        customThemes = []
        customThemeIDs = []
        themeDraft = nil
        logEvent("seed: loaded default bundled project \(defaultProject.id)")
        do {
            try save()
        } catch {
            Logger.persistence.error("Initial seed save failed: \(error.localizedDescription)")
        }
    }

    private func isLegacyBundledListPlaceholder(_ tiers: Items) -> Bool {
        let placeholderIDs = Set(BundledProjects.all.map(\.id))
        guard !placeholderIDs.isEmpty else { return false }

        let allItems = tiers.values.flatMap { $0 }
        guard allItems.count == placeholderIDs.count else { return false }

        let itemIDs = Set(allItems.map(\.id))
        return itemIDs == placeholderIDs
    }

    private func prefillBundledProjectsIfNeeded() {
        do {
            let bundledSource = TierListSource.bundled.rawValue
            let descriptor = FetchDescriptor<TierListEntity>(
                predicate: #Predicate { $0.sourceRaw == bundledSource }
            )
            let existing = try modelContext.fetch(descriptor)
            let existingIdentifiers = Set(existing.compactMap { $0.externalIdentifier })
            var created = false
            for project in bundledProjects where !existingIdentifiers.contains(project.id) {
                let entity = makeBundledTierListEntity(from: project, source: bundledSource)
                modelContext.insert(entity)
                created = true
            }
            if created {
                try modelContext.save()
            }
        } catch {
            Logger.persistence.error("Prefill bundled projects failed: \(error.localizedDescription)")
        }
    }

    private func makeBundledTierListEntity(from project: BundledProject, source: String) -> TierListEntity {
        let entity = TierListEntity(
            title: project.title,
            fileName: nil,
            createdAt: Date(),
            updatedAt: Date(),
            isActive: false,
            cardDensityRaw: cardDensityPreference.rawValue,
            selectedThemeID: selectedThemeID,
            customThemesData: nil,
            sourceRaw: source,
            externalIdentifier: project.id,
            subtitle: project.subtitle,
            iconSystemName: "square.grid.2x2",
            lastOpenedAt: .distantPast,
            tiers: []
        )

        let metadata = Dictionary(uniqueKeysWithValues: project.project.tiers.map { ($0.id, $0) })
        let resolvedTiers = ModelResolver.resolveTiers(from: project.project)

        for (index, resolvedTier) in resolvedTiers.enumerated() {
            let normalizedKey = normalizedTierKey(resolvedTier.label)
            let tierMetadata = metadata[resolvedTier.id]
            let order = normalizedKey == "unranked" ? resolvedTiers.count : index
            let tierEntity = TierEntity(
                key: normalizedKey,
                displayName: resolvedTier.label,
                colorHex: tierMetadata?.color,
                order: order,
                isLocked: tierMetadata?.locked ?? false
            )
            tierEntity.list = entity

            for (position, item) in resolvedTier.items.enumerated() {
                let (seasonString, seasonNumber) = seasonInfo(from: item.attributes)
                let newItem = TierItemEntity(
                    itemID: item.id,
                    name: item.title,
                    seasonString: seasonString,
                    seasonNumber: seasonNumber,
                    status: item.attributes?["status"],
                    details: item.description,
                    imageUrl: item.thumbUri,
                    videoUrl: nil,
                    position: position,
                    tier: tierEntity
                )
                tierEntity.items.append(newItem)
            }

            entity.tiers.append(tierEntity)
        }

        return entity
    }

    private func normalizedTierKey(_ label: String) -> String {
        label.lowercased() == "unranked" ? "unranked" : label
    }

    private func seasonInfo(from attributes: [String: String]?) -> (String?, Int?) {
        guard let attributes else { return (nil, nil) }
        if let seasonNumberString = attributes["seasonNumber"], let value = Int(seasonNumberString) {
            return (seasonNumberString, value)
        }
        if let seasonString = attributes["season"] {
            return (seasonString, Int(seasonString))
        }
        return (nil, nil)
    }

    func undo() {
        if let manager = undoManager, manager.canUndo {
            manager.undo()
            return
        }
    }

    func redo() {
        if let manager = undoManager, manager.canRedo {
            manager.redo()
            return
        }
    }
    var canUndo: Bool { undoManager?.canUndo ?? false }
    var canRedo: Bool { undoManager?.canRedo ?? false }
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
        AccessibilityNotification.Announcement(message).post()
    }
}
