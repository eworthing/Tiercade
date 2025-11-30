import Accessibility
import Foundation
import Observation
import os
import SwiftData
import SwiftUI

import TiercadeCore

// MARK: - ExportFormat

//

nonisolated enum ExportFormat: CaseIterable {
    case text
    case json
    case markdown
    case csv
    case png
    case pdf

    var fileExtension: String {
        switch self {
        case .text: "txt"
        case .json: "json"
        case .markdown: "md"
        case .csv: "csv"
        case .png: "png"
        case .pdf: "pdf"
        }
    }

    var displayName: String {
        switch self {
        case .text: "Plain Text"
        case .json: "JSON"
        case .markdown: "Markdown"
        case .csv: "CSV"
        case .png: "PNG Image"
        case .pdf: "PDF"
        }
    }
}

// MARK: - TierDistributionData

struct TierDistributionData: Identifiable, Sendable {
    let id = UUID()
    let tierId: String // Internal tier identifier (e.g., "S", "GOLD", "EPIC")
    let tierLabel: String // Display label (e.g., "Best", "Golden", "Epic Tier")
    let count: Int
    let percentage: Double

    /// Legacy accessor for backward compatibility with views expecting 'tier' property
    var tier: String { tierLabel }
}

// MARK: - TierAnalysisData

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
        unrankedCount: 0,
    )
}

// MARK: - AppState

@MainActor
@Observable
final class AppState {

    // MARK: Lifecycle

    init(
        modelContext: ModelContext,
        persistenceStore: TierPersistenceStore? = nil,
        listGenerator: UniqueListGenerating? = nil,
        themeCatalog: ThemeCatalogProviding? = nil,
    ) {
        self.modelContext = modelContext

        self.persistenceStore = persistenceStore ?? SwiftDataPersistenceStore(modelContext: modelContext)
        self.listGenerator = listGenerator ?? AppleIntelligenceListGenerator()
        self.themeCatalog = themeCatalog ?? BundledThemeCatalog(modelContext: modelContext)

        self.aiGeneration = AIGenerationState(listGenerator: self.listGenerator)

        self.persistence = PersistenceState(persistenceStore: self.persistenceStore)

        self.theme = ThemeState(themeCatalog: self.themeCatalog)

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
        let unrankedKey = TierIdentifier.unranked.rawValue
        let unrankedCount = tiers[unrankedKey]?.count ?? 0
        let initMsg = "init: tiers counts=\(tierSummary) unranked=\(unrankedCount)"
        logEvent(initMsg)
        restoreTierListState()
        if !didLoad {
            loadActiveTierListIfNeeded()
        }
        prefillBundledProjectsIfNeeded()
    }

    // MARK: Internal

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

    let persistenceStore: TierPersistenceStore
    let listGenerator: UniqueListGenerating
    let themeCatalog: ThemeCatalogProviding

    // MARK: - Tier List State

    /// Consolidated state for tier list data and operations
    var tierList = TierListState()

    var searchQuery: String = ""
    var activeFilter: FilterType = .all
    var currentToast: ToastMessage?
    var quickRankTarget: Item?
    var batchQuickMoveActive: Bool = false

    // MARK: - Layout Preferences

    var cardDensityPreference: CardDensityPreference = .compact

    // MARK: - Debug/Demo

    #if DEBUG
    var showDesignDemo: Bool = false
    #endif
    // Tier List Creator state (active flags for focus management)
    var tierListCreatorActive: Bool = false
    var tierListWizardContext: TierListWizardContext = .create
    var tierListCreatorDraft: TierProjectDraft?
    var tierListCreatorIssues: [TierListDraftValidationIssue] = []
    var tierListCreatorExportPayload: String?

    // MARK: - AI Generation State

    /// Consolidated state for Apple Intelligence chat and AI generation
    var aiGeneration: AIGenerationState

    // MARK: - HeadToHead State

    /// Consolidated state for HeadToHead ranking mode (replaces 17 scattered h2h* properties)
    var headToHead = HeadToHeadState()

    // MARK: - Persistence State

    /// Consolidated state for tier list persistence and file management
    var persistence: PersistenceState

    // MARK: - Overlays State

    /// Consolidated state for modal/overlay routing and visibility
    var overlays = OverlaysState()

    // MARK: - Theme State

    /// Consolidated state for theme selection and management
    var theme: ThemeState

    // MARK: - Progress State

    /// Consolidated state for loading indicators and progress tracking
    var progress = ProgressState()

    // MARK: - Progress Tracking & Visual Feedback

    var dragTargetTier: String?
    var draggingId: String?
    var isProcessingSearch: Bool = false
    let bundledProjects: [BundledProject] = BundledProjects.all

    var showRandomizeConfirmation: Bool = false
    var showResetConfirmation: Bool = false

    let tierListStateKey = "Tiercade.tierlist.active.v1"
    let tierListRecentsKey = "Tiercade.tierlist.recents.v1"
    var autosaveTask: Task<Void, Never>?
    let autosaveInterval: TimeInterval = PersistenceIntervals.autosave

    // MARK: - Analysis & Statistics System

    var showingAnalysis = false
    var analysisData: TierAnalysisData?

    /// Centralized check for whether any overlay blocks background interaction
    /// Use with `.allowsHitTesting(!app.blocksBackgroundFocus)` on background content
    var blocksBackgroundFocus: Bool {
        overlays.blocksBackgroundFocus
            || headToHead.isActive
            || (aiGeneration.showAIChat && AIGenerationState.isSupportedOnCurrentPlatform)
    }

    // MARK: - Tier List Convenience Accessors

    /// Convenience accessor for tiers
    var tiers: Items {
        get { tierList.tiers }
        set { tierList.tiers = newValue }
    }

    /// Convenience accessor for tierOrder
    var tierOrder: [String] {
        get { tierList.tierOrder }
        set { tierList.tierOrder = newValue }
    }

    /// Convenience accessor for selection
    var selection: Set<String> {
        get { tierList.selection }
        set { tierList.selection = newValue }
    }

    /// Convenience accessor for lockedTiers
    var lockedTiers: Set<String> {
        get { tierList.lockedTiers }
        set { tierList.lockedTiers = newValue }
    }

    /// Convenience accessor for tierLabels
    var tierLabels: [String: String] {
        get { tierList.tierLabels }
        set { tierList.tierLabels = newValue }
    }

    /// Convenience accessor for tierColors
    var tierColors: [String: String] {
        get { tierList.tierColors }
        set { tierList.tierColors = newValue }
    }

    /// Convenience accessor for globalSortMode
    var globalSortMode: GlobalSortMode {
        get { tierList.globalSortMode }
        set { tierList.globalSortMode = newValue }
    }

    // MARK: - Progress Convenience Accessors

    /// Convenience accessor for isLoading
    var isLoading: Bool {
        get { progress.isLoading }
        set { progress.isLoading = newValue }
    }

    /// Convenience accessor for loadingMessage
    var loadingMessage: String {
        get { progress.loadingMessage }
        set { progress.loadingMessage = newValue }
    }

    /// Convenience accessor for operationProgress
    var operationProgress: Double {
        get { progress.operationProgress }
        set { progress.operationProgress = newValue }
    }

    var canUndo: Bool { tierList.canUndo }
    var canRedo: Bool { tierList.canRedo }
    var totalItemCount: Int { tierList.totalItemCount }
    var hasAnyItems: Bool { tierList.hasAnyItems }
    var hasEnoughForPairing: Bool { tierList.hasEnoughForPairing }
    var canRandomizeItems: Bool { tierList.canRandomizeItems }
    var canStartHeadToHead: Bool { !headToHead.isActive && hasEnoughForPairing }
    var canShowAnalysis: Bool { hasAnyItems }

    /// Convenience accessor for displayLabel
    func displayLabel(for tierId: String) -> String {
        tierList.displayLabel(for: tierId)
    }

    /// Convenience accessor for displayColorHex
    func displayColorHex(for tierId: String) -> String? {
        tierList.displayColorHex(for: tierId)
    }

    // MARK: - Undo/Redo Management

    func updateUndoManager(_ manager: UndoManager?) {
        tierList.updateUndoManager(manager)
    }

    func captureTierSnapshot() -> TierListState.TierStateSnapshot {
        tierList.captureTierSnapshot()
    }

    func restore(from snapshot: TierListState.TierStateSnapshot) {
        tierList.restore(from: snapshot)
    }

    func finalizeChange(action: String, undoSnapshot: TierListState.TierStateSnapshot) {
        tierList.finalizeChange(action: action, undoSnapshot: undoSnapshot) { [weak self] in
            self?.markAsChanged()
        }

        if tierList.undoManager?.isUndoing == true {
            showInfoToast("Undone", message: "\(action) reverted {undo}")
        } else if tierList.undoManager?.isRedoing == true {
            showInfoToast("Redone", message: "\(action) repeated {redo}")
        }
    }

    func markAsChanged() {
        persistence.hasUnsavedChanges = true
    }

    /// Log a general app state event using unified logging
    func logEvent(_ message: String) {
        Logger.appState.info("\(message)")
    }

    func seed() {
        // Load the first bundled project as default instead of placeholder items
        guard let defaultProject = bundledProjects.first else {
            // Fallback to empty state if no bundled projects available
            tiers[TierIdentifier.unranked.rawValue] = []
            return
        }
        applyBundledProject(defaultProject)
        let fallbackTheme = TierThemeCatalog.defaultTheme
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

    func undo() {
        tierList.undo()
    }

    func redo() {
        tierList.redo()
    }

    // MARK: - Accessibility

    func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    // MARK: Private

    // MARK: - Logging

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

                guard let self else {
                    return
                }
                await performAutosaveIfNeeded()
            }
        }
    }

    @MainActor
    private func performAutosaveIfNeeded() async {
        if persistence.hasUnsavedChanges {
            await autoSaveAsync()
        }
    }

    private func isLegacyBundledListPlaceholder(_ tiers: Items) -> Bool {
        let placeholderIDs = Set(BundledProjects.all.map(\.id))
        guard !placeholderIDs.isEmpty else {
            return false
        }

        let allItems = tiers.values.flatMap(\.self)
        guard allItems.count == placeholderIDs.count else {
            return false
        }

        let itemIDs = Set(allItems.map(\.id))
        return itemIDs == placeholderIDs
    }

}
