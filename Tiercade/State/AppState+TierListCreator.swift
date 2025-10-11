import Foundation
import SwiftUI
import SwiftData
import os
import TiercadeCore

@MainActor
extension AppState {
    enum TierListDraftCommitAction {
        case save
        case publish
    }

    // MARK: - Presentation

    func presentTierListCreator() {
        if tierListCreatorDraft == nil {
            tierListCreatorDraft = TierProjectDraft.makeDefault()
        }
        tierListCreatorIssues.removeAll()
        showTierListCreator = true
        tierListCreatorActive = true
    }

    func dismissTierListCreator(resetDraft: Bool = false) {
        tierListCreatorActive = false
        showTierListCreator = false
        if resetDraft {
            tierListCreatorDraft = nil
        }
    }

    func cancelTierListCreator() {
        dismissTierListCreator(resetDraft: false)
    }

    // MARK: - Draft Editing Helpers

    @discardableResult
    func addTier(to draft: TierProjectDraft) -> TierDraftTier {
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

    func delete(_ tier: TierDraftTier, from draft: TierProjectDraft) {
        guard let index = draft.tiers.firstIndex(where: { $0.identifier == tier.identifier }) else { return }
        draft.tiers.remove(at: index)
        for item in draft.items where item.tier?.identifier == tier.identifier {
            item.tier = nil
        }
        normalizeTierOrdering(for: draft)
        markDraftEdited(draft)
    }

    func moveTier(_ tier: TierDraftTier, direction: Int, in draft: TierProjectDraft) {
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

    func toggleLock(_ tier: TierDraftTier, in draft: TierProjectDraft) {
        tier.locked.toggle()
        markDraftEdited(draft)
    }

    func toggleCollapse(_ tier: TierDraftTier, in draft: TierProjectDraft) {
        tier.collapsed.toggle()
        markDraftEdited(draft)
    }

    func addItem(to draft: TierProjectDraft) -> TierDraftItem {
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

    func delete(_ item: TierDraftItem, from draft: TierProjectDraft) {
        guard let index = draft.items.firstIndex(where: { $0.identifier == item.identifier }) else { return }
        draft.items.remove(at: index)
        markDraftEdited(draft)
    }

    func assign(_ item: TierDraftItem, to tier: TierDraftTier?, in draft: TierProjectDraft) {
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

    func reorderItems(in tier: TierDraftTier, from source: IndexSet, to destination: Int) {
        var current = tier.items.sorted(by: { $0.ordinal < $1.ordinal })
        current.move(fromOffsets: source, toOffset: destination)
        for (index, item) in current.enumerated() {
            item.ordinal = index
        }
    }

    func updateTag(_ tag: String, for item: TierDraftItem, isAdding: Bool) {
        if isAdding {
            guard item.tags.contains(tag) == false else { return }
            item.tags.append(tag)
        } else {
            item.tags.removeAll { $0 == tag }
        }
    }

    func markDraftEdited(_ draft: TierProjectDraft, timestamp: Date = Date()) {
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

    func orderedTiers(for draft: TierProjectDraft) -> [TierDraftTier] {
        draft.tiers.sorted { lhs, rhs in
            if lhs.order == rhs.order {
                return lhs.label.localizedCompare(rhs.label) == .orderedAscending
            }
            return lhs.order < rhs.order
        }
    }

    func orderedItems(for tier: TierDraftTier) -> [TierDraftItem] {
        tier.items.sorted { lhs, rhs in
            if lhs.ordinal == rhs.ordinal {
                return lhs.title.localizedCompare(rhs.title) == .orderedAscending
            }
            return lhs.ordinal < rhs.ordinal
        }
    }

    func unassignedItems(for draft: TierProjectDraft) -> [TierDraftItem] {
        draft.items.filter { $0.tier == nil }
    }

    // MARK: - Validation & Export

    func validateTierListDraft() -> [TierListDraftValidationIssue] {
        guard let draft = tierListCreatorDraft else { return [] }
        var issues: [TierListDraftValidationIssue] = []

        if draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.init(category: .project, message: "Project title is required."))
        }

        if draft.tiers.isEmpty {
            issues.append(.init(category: .tier, message: "Add at least one tier before saving."))
        }

        let tierIds = draft.tiers.map { $0.tierId.lowercased() }
        if Set(tierIds).count != tierIds.count {
            issues.append(.init(category: .tier, message: "Tier identifiers must be unique."))
        }

        let colorRegex = try? NSRegularExpression(pattern: "^#?[0-9A-Fa-f]{6}$")
        for tier in draft.tiers {
            if colorRegex?.firstMatch(in: tier.colorHex, options: [], range: NSRange(location: 0, length: tier.colorHex.count)) == nil {
                issues.append(
                    .init(
                        category: .tier,
                        message: "Tier \(tier.label) has an invalid color hex value.",
                        contextIdentifier: tier.identifier.uuidString
                    )
                )
            }
        }

        for item in draft.items {
            if item.itemId.trimmingCharacters(in: .whitespaces).isEmpty {
                issues.append(
                    .init(
                        category: .item,
                        message: "Every item must have a stable identifier.",
                        contextIdentifier: item.identifier.uuidString
                    )
                )
            }
            if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(
                    .init(
                        category: .item,
                        message: "Item identifiers \(item.itemId) require a display title.",
                        contextIdentifier: item.identifier.uuidString
                    )
                )
            }
        }

        for media in draft.mediaLibrary {
            if media.uri.isEmpty || media.mime.isEmpty {
                issues.append(
                    .init(
                        category: .media,
                        message: "Media assets require both a URI and MIME type.",
                        contextIdentifier: media.identifier.uuidString
                    )
                )
            }
        }

        tierListCreatorIssues = issues
        return issues
    }

    func exportTierListDraftPayload() -> String? {
        guard let draft = tierListCreatorDraft else { return nil }
        do {
            let project = try buildProject(from: draft)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(project)
            return String(data: data, encoding: .utf8)
        } catch {
            Logger.appState.error("Draft export failed: \(error.localizedDescription)")
            showToast(type: .error, title: "Export Failed", message: error.localizedDescription)
            return nil
        }
    }

    func saveTierListDraft(action: TierListDraftCommitAction) async {
        guard let draft = tierListCreatorDraft else { return }
        let issues = validateTierListDraft()
        guard issues.isEmpty else {
            showToast(
                type: .warning,
                title: "Needs Attention",
                message: issues.first?.message ?? "Resolve validation issues before saving."
            )
            return
        }

        await withLoadingIndicator(message: action == .publish ? "Publishing Project..." : "Saving Project...") {
            do {
                let entity = try persistProjectDraft(draft)
                try modelContext.save()
                tierListCreatorDraft = nil
                dismissTierListCreator(resetDraft: true)
                let handle = AppState.TierListHandle(entity: entity)
                registerTierListSelection(handle)
                showToast(
                    type: .success,
                    title: action == .publish ? "Project Published" : "Draft Saved",
                    message: "\(entity.title) is ready to rank."
                )
            } catch {
                Logger.appState.error("Failed to persist draft: \(error.localizedDescription)")
                showToast(type: .error, title: "Save Failed", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Persistence Helpers

    private func persistProjectDraft(_ draft: TierProjectDraft) throws -> TierListEntity {
        let now = Date()
        draft.audit?.updatedAt = now
        draft.updatedAt = now

        if let existing = try fetchPersistedDraftEntity(for: draft.projectId) {
            modelContext.delete(existing)
            try modelContext.save()
        }

        let entity = TierListEntity(
            identifier: draft.projectId,
            title: draft.title.isEmpty ? "Untitled Project" : draft.title,
            fileName: nil,
            createdAt: draft.audit?.createdAt ?? now,
            updatedAt: now,
            isActive: true,
            cardDensityRaw: cardDensityPreference.rawValue,
            selectedThemeID: selectedThemeID,
            customThemesData: encodedCustomThemesData(),
            sourceRaw: TierListSource.authored.rawValue,
            externalIdentifier: draft.projectId.uuidString,
            subtitle: draft.summary.isEmpty ? nil : draft.summary,
            iconSystemName: "square.and.pencil",
            lastOpenedAt: now,
            tiers: []
        )

        var rankedTiers: [TierEntity] = []
        let ordered = orderedTiers(for: draft)
        for (index, tierDraft) in ordered.enumerated() {
            let tierEntity = TierEntity(
                key: normalizedTierKey(tierDraft.tierId),
                displayName: tierDraft.label,
                colorHex: tierDraft.colorHex,
                order: index,
                isLocked: tierDraft.locked,
                items: []
            )
            tierEntity.list = entity

            let items = orderedItems(for: tierDraft)
            for (position, draftItem) in items.enumerated() {
                let resolved = makeTierItemEntity(from: draftItem, position: position, tier: tierEntity)
                tierEntity.items.append(resolved)
            }
            rankedTiers.append(tierEntity)
        }

        let unassigned = draft.items.filter { $0.tier == nil }
        if !unassigned.isEmpty {
            let unranked = TierEntity(
                key: "unranked",
                displayName: "Unranked",
                colorHex: "#6B7280",
                order: rankedTiers.count,
                isLocked: false,
                items: []
            )
            unranked.list = entity
            for (position, item) in unassigned.enumerated() {
                let resolved = makeTierItemEntity(from: item, position: position, tier: unranked)
                unranked.items.append(resolved)
            }
            rankedTiers.append(unranked)
        }

        entity.tiers = rankedTiers
        modelContext.insert(entity)
        return entity
    }

    private func fetchPersistedDraftEntity(for identifier: UUID) throws -> TierListEntity? {
        let descriptor = FetchDescriptor<TierListEntity>(
            predicate: #Predicate { $0.identifier == identifier }
        )
        return try modelContext.fetch(descriptor).first
    }

    private func makeTierItemEntity(from draftItem: TierDraftItem, position: Int, tier: TierEntity) -> TierItemEntity {
        let media = draftItem.media.first
        let entity = TierItemEntity(
            itemID: draftItem.itemId,
            name: draftItem.title,
            seasonString: draftItem.attributes["season"].flatMap { value in
                if case let .string(text) = value { return text }
                return nil
            },
            seasonNumber: draftItem.attributes["seasonNumber"].flatMap { value in
                if case let .number(number) = value { return Int(number) }
                return nil
            },
            status: draftItem.attributes["status"].flatMap { value in
                if case let .string(text) = value { return text }
                return nil
            },
            details: draftItem.summary.isEmpty ? nil : draftItem.summary,
            imageUrl: media?.thumbUri,
            videoUrl: media?.uri,
            position: position,
            tier: tier
        )
        return entity
    }

    private func normalizedTierKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "unranked" {
            return "unranked"
        }
        return trimmed
    }

    private func buildProject(from draft: TierProjectDraft) throws -> Project {
        let tiers = orderedTiers(for: draft).map { tier -> Project.Tier in
            let itemIds = orderedItems(for: tier).map(\.itemId)
            return Project.Tier(
                id: tier.tierId,
                label: tier.label,
                color: tier.colorHex,
                order: tier.order,
                locked: tier.locked ? true : nil,
                collapsed: tier.collapsed ? true : nil,
                rules: tier.rules.isEmpty ? nil : tier.rules,
                itemIds: itemIds,
                additional: tier.additional.isEmpty ? nil : tier.additional
            )
        }

        var items: [String: Project.Item] = [:]
        for item in draft.items {
            let media = item.media.map { $0.toProjectMedia() }
            let projectItem = Project.Item(
                id: item.itemId,
                title: item.title,
                subtitle: item.subtitle.isEmpty ? nil : item.subtitle,
                summary: item.summary.isEmpty ? nil : item.summary,
                slug: item.slug.isEmpty ? nil : item.slug,
                media: media.isEmpty ? nil : media,
                attributes: item.attributes.isEmpty ? nil : item.attributes,
                tags: item.tags.isEmpty ? nil : item.tags,
                rating: item.rating,
                sources: item.sources.isEmpty ? nil : item.sources,
                locale: item.locale.isEmpty ? nil : item.locale,
                meta: item.meta,
                additional: item.additional.isEmpty ? nil : item.additional
            )
            items[item.itemId] = projectItem
        }

        var overrides: [String: Project.ItemOverride] = [:]
        for override in draft.overrides {
            let media = override.media.map { $0.toProjectMedia() }
            overrides[override.itemId] = Project.ItemOverride(
                displayTitle: override.displayTitle.isEmpty ? nil : override.displayTitle,
                notes: override.notes.isEmpty ? nil : override.notes,
                tags: override.tags.isEmpty ? nil : override.tags,
                rating: override.rating,
                media: media.isEmpty ? nil : media,
                hidden: override.hidden ? true : nil,
                additional: override.additional.isEmpty ? nil : override.additional
            )
        }

        let audit = draft.audit?.projectAudit ?? Project.Audit(createdAt: draft.createdAt, updatedAt: draft.updatedAt)

        return Project(
            schemaVersion: draft.schemaVersion,
            projectId: draft.projectId.uuidString,
            title: draft.title.isEmpty ? nil : draft.title,
            description: draft.summary.isEmpty ? nil : draft.summary,
            tiers: tiers,
            items: items,
            overrides: overrides.isEmpty ? nil : overrides,
            links: draft.links,
            storage: draft.storage,
            settings: draft.settings,
            collab: draft.collaboration,
            audit: audit,
            additional: draft.additional
        )
    }

    private func normalizeTierOrdering(for draft: TierProjectDraft) {
        for (index, tier) in orderedTiers(for: draft).enumerated() {
            tier.order = index
        }
    }
}

private enum TierListCreatorPalette {
    private static let colors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#AF52DE",
        "#FF2D55", "#5AC8FA", "#FF9F0A", "#FFD60A"
    ]

    static func color(for index: Int) -> String {
        guard index >= 0 else { return colors.first ?? "#FF3B30" }
        return colors[index % colors.count]
    }
}
