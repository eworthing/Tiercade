import Foundation
import SwiftUI
import Observation
import SwiftData
import Accessibility
import os

import TiercadeCore

// Use core Item/Items and core logic directly (breaking change)

// MARK: - Export & Import System Types

internal nonisolated enum ExportFormat: CaseIterable {
    case text, json, markdown, csv, png, pdf

    internal var fileExtension: String {
        switch self {
        case .text: return "txt"
        case .json: return "json"
        case .markdown: return "md"
        case .csv: return "csv"
        case .png: return "png"
        case .pdf: return "pdf"
        }
    }

    internal var displayName: String {
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
    internal let id = UUID()
    internal let tier: String
    internal let count: Int
    internal let percentage: Double
}

internal struct TierAnalysisData: Sendable {
    internal let totalItems: Int
    internal let tierDistribution: [TierDistributionData]
    internal let mostPopulatedTier: String?
    internal let leastPopulatedTier: String?
    internal let balanceScore: Double
    internal let insights: [String]
    internal let unrankedCount: Int

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
    internal enum TierListDraftValidationCategory: String, Sendable {
        case project
        case tier
        case item
        case override
        case media
        case collaboration
    }

    internal struct TierListDraftValidationIssue: Identifiable, Equatable, Sendable {
        internal let id = UUID()
        internal var category: TierListDraftValidationCategory
        internal var message: String
        internal var contextIdentifier: String?
    }

    internal let modelContext: ModelContext

    // MARK: - Injected Services (DI)
    internal let persistenceStore: TierPersistenceStore
    internal let listGenerator: UniqueListGenerating
    internal let themeCatalog: ThemeCatalogProviding

    // MARK: - Tier List State
    /// Consolidated state for tier list data and operations
    internal var tierList = TierListState()

    internal var searchQuery: String = ""
    internal var activeFilter: FilterType = .all
    internal var currentToast: ToastMessage?
    internal var quickRankTarget: Item?
    internal var batchQuickMoveActive: Bool = false
    // Layout preferences
    internal var cardDensityPreference: CardDensityPreference = .compact
    // Tier List Creator state (active flags for focus management)
    internal var tierListCreatorActive: Bool = false
    internal var tierListWizardContext: TierListWizardContext = .create
    internal var tierListCreatorDraft: TierProjectDraft?
    internal var tierListCreatorIssues: [TierListDraftValidationIssue] = []
    internal var tierListCreatorExportPayload: String?
    // MARK: - AI Generation State
    /// Consolidated state for Apple Intelligence chat and AI generation
    internal var aiGeneration: AIGenerationState

    // MARK: - Head-to-Head State
    /// Consolidated state for Head-to-Head ranking mode (replaces 17 scattered h2h* properties)
    internal var headToHead = HeadToHeadState()

    // MARK: - Persistence State
    /// Consolidated state for tier list persistence and file management
    internal var persistence: PersistenceState

    // MARK: - Overlays State
    /// Consolidated state for modal/overlay routing and visibility
    internal var overlays = OverlaysState()

    // MARK: - Theme State
    /// Consolidated state for theme selection and management
    internal var theme: ThemeState

    // MARK: - Progress State
    /// Consolidated state for loading indicators and progress tracking
    internal var progress = ProgressState()

    // Progress Tracking & Visual Feedback
    internal var dragTargetTier: String?
    internal var draggingId: String?
    internal var isProcessingSearch: Bool = false
    internal let bundledProjects: [BundledProject] = BundledProjects.all

    // Confirmation alerts
    internal var showRandomizeConfirmation: Bool = false
    internal var showResetConfirmation: Bool = false

    internal let tierListStateKey = "Tiercade.tierlist.active.v1"
    internal let tierListRecentsKey = "Tiercade.tierlist.recents.v1"
    internal var autosaveTask: Task<Void, Never>?
    internal let autosaveInterval: TimeInterval = PersistenceIntervals.autosave

    /// Centralized check for whether any overlay blocks background interaction
    /// Use with `.allowsHitTesting(!app.blocksBackgroundFocus)` on background content
    internal var blocksBackgroundFocus: Bool {
        overlays.blocksBackgroundFocus
        || headToHead.isActive
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

        // Initialize theme state with injected theme catalog
        self.theme = ThemeState(themeCatalog: self.themeCatalog)

        internal let didLoad = load()
        if !didLoad {
            seed()
        } else if isLegacyBundledListPlaceholder(tiers) {
            logEvent("init: detected legacy bundled list placeholder; reseeding default project")
            internal let defaults = UserDefaults.standard
            defaults.removeObject(forKey: tierListStateKey)
            defaults.removeObject(forKey: tierListRecentsKey)
            seed()
        }
        setupAutosave()

        internal let tierSummary = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        internal let unrankedKey = TierIdentifier.unranked.rawValue
        internal let unrankedCount = tiers[unrankedKey]?.count ?? 0
        internal let initMsg = "init: tiers counts=\(tierSummary) unranked=\(unrankedCount)"
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
        internal let interval = autosaveInterval
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

    // MARK: - Tier List Convenience Accessors

    /// Convenience accessor for tiers
    internal var tiers: Items {
        get { tierList.tiers }
        set { tierList.tiers = newValue }
    }

    /// Convenience accessor for tierOrder
    internal var tierOrder: [String] {
        get { tierList.tierOrder }
        set { tierList.tierOrder = newValue }
    }

    /// Convenience accessor for selection
    internal var selection: Set<String> {
        get { tierList.selection }
        set { tierList.selection = newValue }
    }

    /// Convenience accessor for lockedTiers
    internal var lockedTiers: Set<String> {
        get { tierList.lockedTiers }
        set { tierList.lockedTiers = newValue }
    }

    /// Convenience accessor for tierLabels
    internal var tierLabels: [String: String] {
        get { tierList.tierLabels }
        set { tierList.tierLabels = newValue }
    }

    /// Convenience accessor for tierColors
    internal var tierColors: [String: String] {
        get { tierList.tierColors }
        set { tierList.tierColors = newValue }
    }

    /// Convenience accessor for globalSortMode
    internal var globalSortMode: GlobalSortMode {
        get { tierList.globalSortMode }
        set { tierList.globalSortMode = newValue }
    }

    /// Convenience accessor for displayLabel
    internal func displayLabel(for tierId: String) -> String {
        tierList.displayLabel(for: tierId)
    }

    /// Convenience accessor for displayColorHex
    internal func displayColorHex(for tierId: String) -> String? {
        tierList.displayColorHex(for: tierId)
    }

    // MARK: - Progress Convenience Accessors

    /// Convenience accessor for isLoading
    internal var isLoading: Bool {
        get { progress.isLoading }
        set { progress.isLoading = newValue }
    }

    /// Convenience accessor for loadingMessage
    internal var loadingMessage: String {
        get { progress.loadingMessage }
        set { progress.loadingMessage = newValue }
    }

    /// Convenience accessor for operationProgress
    internal var operationProgress: Double {
        get { progress.operationProgress }
        set { progress.operationProgress = newValue }
    }

    // MARK: - Undo/Redo Management

    internal func updateUndoManager(_ manager: UndoManager?) {
        tierList.updateUndoManager(manager)
    }

    internal func captureTierSnapshot() -> TierListState.TierStateSnapshot {
        tierList.captureTierSnapshot()
    }

    internal func restore(from snapshot: TierListState.TierStateSnapshot) {
        tierList.restore(from: snapshot)
    }

    internal func finalizeChange(action: String, undoSnapshot: TierListState.TierStateSnapshot) {
        tierList.finalizeChange(action: action, undoSnapshot: undoSnapshot) { [weak self] in
            self?.markAsChanged()
        }

        // Show toast for undo/redo operations
        if tierList.undoManager?.isUndoing == true {
            showInfoToast("Undone", message: "\(action) reverted {undo}")
        } else if tierList.undoManager?.isRedoing == true {
            showInfoToast("Redone", message: "\(action) repeated {redo}")
        }
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
            tiers[TierIdentifier.unranked.rawValue] = []
            return
        }
        applyBundledProject(defaultProject)
        internal let fallbackTheme = TierThemeCatalog.defaultTheme
        theme.selectedTheme = fallbackTheme
        theme.selectedThemeID = fallbackTheme.id
        applyCurrentTheme()
        cardDensityPreference = .compact
        theme.customThemes = []
        theme.customThemeIDs = []
        theme.themeDraft = nil
        logEvent("seed: loaded default bundled project \(defaultProject.id)")
        do {
            try save()
        } catch {
            Logger.persistence.error("Initial seed save failed: \(error.localizedDescription)")
        }
    }

    private func isLegacyBundledListPlaceholder(_ tiers: Items) -> Bool {
        internal let placeholderIDs = Set(BundledProjects.all.map(\.id))
        guard !placeholderIDs.isEmpty else { return false }

        internal let allItems = tiers.values.flatMap { $0 }
        guard allItems.count == placeholderIDs.count else { return false }

        internal let itemIDs = Set(allItems.map(\.id))
        return itemIDs == placeholderIDs
    }

    internal func undo() {
        tierList.undo()
    }

    internal func redo() {
        tierList.redo()
    }

    internal var canUndo: Bool { tierList.canUndo }
    internal var canRedo: Bool { tierList.canRedo }
    internal var totalItemCount: Int { tierList.totalItemCount }
    internal var hasAnyItems: Bool { tierList.hasAnyItems }
    internal var hasEnoughForPairing: Bool { tierList.hasEnoughForPairing }
    internal var canRandomizeItems: Bool { tierList.canRandomizeItems }
    internal var canStartHeadToHead: Bool { !headToHead.isActive && hasEnoughForPairing }
    internal var canShowAnalysis: Bool { hasAnyItems }

    // MARK: - Enhanced Persistence

    // MARK: - Async File Operations with Progress Tracking

    // Export/import helpers moved to AppState+ExportImport.swift

    // MARK: - Analysis & Statistics System

    internal var showingAnalysis = false
    internal var analysisData: TierAnalysisData?

    // MARK: - Accessibility
    internal func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}
