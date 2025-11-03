import Foundation
import SwiftUI
import SwiftData
import os
import TiercadeCore

@MainActor
internal extension AppState {
    enum TierListWizardContext: Equatable, Sendable {
        case create
        case edit(TierListHandle)
    }

    enum TierListDraftCommitAction {
        case save
        case publish
    }

    // MARK: - Presentation

    internal func presentTierListCreator() {
        tierListWizardContext = .create
        tierListCreatorDraft = TierProjectDraft.makeDefault()
        tierListCreatorIssues.removeAll()
        showTierListCreator = true
        tierListCreatorActive = true
    }

    internal func dismissTierListCreator(resetDraft: Bool = false) {
        tierListCreatorActive = false
        showTierListCreator = false
        tierListWizardContext = .create
        if resetDraft {
            tierListCreatorDraft = nil
        }
    }

    internal func cancelTierListCreator() {
        dismissTierListCreator(resetDraft: false)
    }

    internal func presentTierListEditor(for handle: TierListHandle) async {
        await selectTierList(handle)

        guard let project = projectForEditor(from: handle) else {
            Logger.appState.error("presentTierListEditor: unresolved project for handle \(handle.id, privacy: .public)")
            showToast(
                type: .error,
                title: "Unable to Edit",
                message: "This tier list could not be loaded. It may have been deleted or corrupted."
            )
            return
        }

        tierListCreatorDraft = TierProjectDraft.make(from: project)
        tierListWizardContext = .edit(handle)
        tierListCreatorIssues.removeAll()
        showingTierListBrowser = false
        showTierListCreator = true
        tierListCreatorActive = true
    }

    private func projectForEditor(from handle: TierListHandle) -> Project? {
        if let entity = persistence.activeTierListEntity {
            if let data = entity.projectData {
                do {
                    return try TierListCreatorCodec.makeDecoder().decode(Project.self, from: data)
                } catch {
                    Logger.appState.error(
                        """
                        Failed to decode stored projectData for handle \(handle.id, privacy: .public): \
                        \(error.localizedDescription, privacy: .public)
                        """
                    )
                }
            }
            return project(from: entity, source: handle.source)
        }
        return projectFromInMemoryState(source: handle.source)
    }

    // MARK: - Draft Editing Helpers

    @discardableResult
    internal func addTier(to draft: TierProjectDraft) -> TierDraftTier {
        let nextIndex = (draft.tiers.map(\.order).max() ?? -1) + 1
        let tierId = "custom-tier-\(UUID().uuidString)"
        let tier = TierDraftTier(
            tierId: tierId,
            label: "Tier \(nextIndex + 1)",
            colorHex: TierListCreatorPalette.color(for: nextIndex),
            order: nextIndex
        )
        tier.project = draft
        draft.tiers.append(tier)
        markDraftEdited(draft)
        return tier
    }

    internal func delete(_ tier: TierDraftTier, from draft: TierProjectDraft) {
        guard let index = draft.tiers.firstIndex(where: { $0.identifier == tier.identifier }) else { return }
        draft.tiers.remove(at: index)
        for item in draft.items where item.tier?.identifier == tier.identifier {
            item.tier = nil
        }
        normalizeTierOrdering(for: draft)
        markDraftEdited(draft)
    }

    internal func moveTier(_ tier: TierDraftTier, direction: Int, in draft: TierProjectDraft) {
        guard let currentIndex = orderedTiers(for: draft).firstIndex(where: { $0.identifier == tier.identifier }) else {
            return
        }
        let destination = max(0, min(currentIndex + direction, draft.tiers.count - 1))
        guard destination != currentIndex else { return }
        var ordered = orderedTiers(for: draft)
        ordered.remove(at: currentIndex)
        ordered.insert(tier, at: destination)
        for (index, element) in ordered.enumerated() {
            element.order = index
        }
        markDraftEdited(draft)
    }

    internal func toggleLock(_ tier: TierDraftTier, in draft: TierProjectDraft) {
        tier.locked.toggle()
        markDraftEdited(draft)
    }

    internal func toggleCollapse(_ tier: TierDraftTier, in draft: TierProjectDraft) {
        tier.collapsed.toggle()
        markDraftEdited(draft)
    }

    internal func addItem(to draft: TierProjectDraft) -> TierDraftItem {
        let identifier = "item-\(UUID().uuidString.lowercased())"
        let item = TierDraftItem(
            itemId: identifier,
            title: "New Item",
            slug: identifier
        )
        item.project = draft
        draft.items.append(item)
        markDraftEdited(draft)
        return item
    }

    internal func delete(_ item: TierDraftItem, from draft: TierProjectDraft) {
        guard let index = draft.items.firstIndex(where: { $0.identifier == item.identifier }) else { return }
        draft.items.remove(at: index)
        markDraftEdited(draft)
    }

    internal func assign(_ item: TierDraftItem, to tier: TierDraftTier?, in draft: TierProjectDraft) {
        if let previous = item.tier,
           let previousIndex = previous.items.firstIndex(where: { $0.identifier == item.identifier }) {
            previous.items.remove(at: previousIndex)
        }
        item.tier = tier
        if let tier, tier.items.contains(where: { $0.identifier == item.identifier }) == false {
            tier.items.append(item)
            item.ordinal = (tier.items.map(\.ordinal).max() ?? -1) + 1
        }
        markDraftEdited(draft)
    }

    internal func reorderItems(in tier: TierDraftTier, from source: IndexSet, to destination: Int) {
        var current = tier.items.sorted(by: { $0.ordinal < $1.ordinal })
        current.move(fromOffsets: source, toOffset: destination)
        for (index, item) in current.enumerated() {
            item.ordinal = index
        }
        if let draft = tier.project {
            markDraftEdited(draft)
        }
    }

    internal func updateTag(_ tag: String, for item: TierDraftItem, isAdding: Bool) {
        if isAdding {
            guard item.tags.contains(tag) == false else { return }
            item.tags.append(tag)
        } else {
            item.tags.removeAll { $0 == tag }
        }
        if let draft = item.project {
            markDraftEdited(draft)
        }
    }

    internal func markDraftEdited(_ draft: TierProjectDraft, timestamp: Date = Date()) {
        draft.updatedAt = timestamp
        if let audit = draft.audit {
            audit.updatedAt = timestamp
            audit.updatedBy = audit.updatedBy ?? createdByFallback()
        }
    }

    private func createdByFallback() -> String {
        if let createdBy = tierListCreatorDraft?.audit?.createdBy, !createdBy.isEmpty {
            return createdBy
        }
        return "local-user"
    }

    internal func orderedTiers(for draft: TierProjectDraft) -> [TierDraftTier] {
        draft.tiers.sorted { lhs, rhs in
            if lhs.order == rhs.order {
                return lhs.label.localizedCompare(rhs.label) == .orderedAscending
            }
            return lhs.order < rhs.order
        }
    }

    internal func orderedItems(for tier: TierDraftTier) -> [TierDraftItem] {
        tier.items.sorted { lhs, rhs in
            if lhs.ordinal == rhs.ordinal {
                return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
            return lhs.ordinal < rhs.ordinal
        }
    }

    internal func unassignedItems(for draft: TierProjectDraft) -> [TierDraftItem] {
        draft.items.filter { $0.tier == nil }
    }

}
