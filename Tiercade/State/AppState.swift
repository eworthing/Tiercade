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

internal struct TierDistributionData: Identifiable, Sendable {
    let id = UUID()
    let tier: String
    let count: Int
    let percentage: Double
}

internal struct TierAnalysisData: Sendable {
    let totalItems: Int
    let tierDistribution: [TierDistributionData]
    let mostPopulatedTier: String?
    let leastPopulatedTier: String?
    let balanceScore: Double
    let insights: [String]
    let unrankedCount: Int

    internal static let empty = TierAnalysisData(
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

    enum TierListDraftValidationCategory: String, Sendable {
        case project
        case tier
        case item
        case override
        case media
        case collaboration
    }

    struct TierListDraftValidationIssue: Identifiable, Equatable, Sendable {
        let id = UUID()
        var category: TierListDraftValidationCategory
        var message: String
        var contextIdentifier: String?
    }

    let modelContext: ModelContext

    // MARK: - Injected Services (DI)
    internal let persistenceStore: TierPersistenceStore
    internal let listGenerator: UniqueListGenerating
    internal let themeCatalog: ThemeCatalogProviding

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
    // Global sort mode for all tiers (default: alphabetical A-Z)
    var globalSortMode: GlobalSortMode = .alphabetical(ascending: true)
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
    var showTierListCreator: Bool = false
    var tierListCreatorActive: Bool = false
    var tierListWizardContext: TierListWizardContext = .create
    var tierListCreatorDraft: TierProjectDraft?
    var tierListCreatorIssues: [TierListDraftValidationIssue] = []
    var tierListCreatorExportPayload: String?
    // MARK: - AI Generation State
    /// Consolidated state for Apple Intelligence chat and AI generation
    var aiGeneration: AIGenerationState

    // MARK: - Head-to-Head State
    /// Consolidated state for Head-to-Head ranking mode (replaces 17 scattered h2h* properties)
    var headToHead = HeadToHeadState()

    // MARK: - Persistence State
    /// Consolidated state for tier list persistence and file management
    var persistence: PersistenceState

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

    // Confirmation alerts
    var showRandomizeConfirmation: Bool = false
    var showResetConfirmation: Bool = false

    let tierListStateKey = "Tiercade.tierlist.active.v1"
    let tierListRecentsKey = "Tiercade.tierlist.recents.v1"
    var autosaveTask: Task<Void, Never>?
    let autosaveInterval: TimeInterval = 30.0 // Auto-save every 30 seconds

    var undoManager: UndoManager?
    private var isPerformingUndoRedo = false

    /// Centralized check for whether any overlay blocks background interaction
    /// Use with `.allowsHitTesting(!app.blocksBackgroundFocus)` on background content
    var blocksBackgroundFocus: Bool {
        (detailItem != nil)
        || headToHead.isActive
        || showThemePicker
        || (quickMoveTarget != nil)
        || showThemeCreator
        || showTierListCreator
        || (aiGeneration.showAIChat && AIGenerationState.isSupportedOnCurrentPlatform)
    }

    internal init(
        modelContext: ModelContext,
        persistenceStore: TierPersistenceStore? = nil,
        listGenerator: UniqueListGenerating? = nil,
        themeCatalog: ThemeCatalogProviding? = nil
    ) {
        self.modelContext = modelContext

        // Initialize services with provided implementations or defaults
        self.persistenceStore = persistenceStore ?? SwiftDataPersistenceStore(modelContext: modelContext)
        self.listGenerator = listGenerator ?? AppleIntelligenceListGenerator()
        self.themeCatalog = themeCatalog ?? BundledThemeCatalog(modelContext: modelContext)

        // Initialize AI generation state with injected list generator
        self.aiGeneration = AIGenerationState(listGenerator: self.listGenerator)

        // Initialize persistence state with injected persistence store
        self.persistence = PersistenceState(persistenceStore: self.persistenceStore)

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
        if persistence.hasUnsavedChanges {
            await autoSaveAsync()
        }
    }

    internal func updateUndoManager(_ manager: UndoManager?) {
        undoManager = manager
    }

    internal func captureTierSnapshot() -> TierStateSnapshot {
        TierStateSnapshot(
            tiers: tiers,
            tierOrder: tierOrder,
            tierLabels: tierLabels,
            tierColors: tierColors,
            lockedTiers: lockedTiers
        )
    }

    internal func restore(from snapshot: TierStateSnapshot) {
        tiers = snapshot.tiers
        tierOrder = snapshot.tierOrder
        tierLabels = snapshot.tierLabels
        tierColors = snapshot.tierColors
        lockedTiers = snapshot.lockedTiers
    }

    internal func finalizeChange(action: String, undoSnapshot: TierStateSnapshot) {
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

    internal func markAsChanged() {
        persistence.hasUnsavedChanges = true
    }

    /// Log a general app state event using unified logging
    internal func logEvent(_ message: String) {
        Logger.appState.info("\(message)")
    }

    internal func seed() {
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

    internal func undo() {
        if let manager = undoManager, manager.canUndo {
            manager.undo()
            return
        }
    }

    internal func redo() {
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
    var canStartHeadToHead: Bool { !headToHead.isActive && hasEnoughForPairing }
    var canShowAnalysis: Bool { hasAnyItems }

    // MARK: - Enhanced Persistence

    // MARK: - Async File Operations with Progress Tracking

    // Export/import helpers moved to AppState+ExportImport.swift

    // MARK: - Analysis & Statistics System

    var showingAnalysis = false
    var analysisData: TierAnalysisData?

    // MARK: - Accessibility
    internal func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}
