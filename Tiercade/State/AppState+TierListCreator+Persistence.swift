import Foundation
import SwiftUI
import SwiftData
import os
import TiercadeCore

@MainActor
internal extension AppState {
    // MARK: - Persistence Helpers

    func persistProjectDraft(_ draft: TierProjectDraft) throws -> TierListEntity {
        let now = Date()
        draft.audit?.updatedAt = now
        draft.updatedAt = now

        let project = try buildProject(from: draft)
        let projectData = try TierListCreatorCodec.makeEncoder().encode(project)

        if let existing = try fetchPersistedDraftEntity(for: draft.projectId) {
            update(
                entity: existing,
                with: draft,
                projectData: projectData,
                timestamp: now
            )
            return existing
        }

        let entity = createTierListEntity(from: draft, projectData: projectData, now: now)
        let rankedTiers = buildTierEntities(for: draft, listEntity: entity)
        entity.tiers = rankedTiers
        modelContext.insert(entity)
        return entity
    }

    private func update(
        entity: TierListEntity,
        with draft: TierProjectDraft,
        projectData: Data,
        timestamp: Date
    ) {
        entity.title = draft.title.isEmpty ? "Untitled Project" : draft.title
        entity.subtitle = draft.summary.isEmpty ? nil : draft.summary
        entity.updatedAt = timestamp
        entity.lastOpenedAt = timestamp
        entity.projectData = projectData
        entity.cardDensityRaw = cardDensityPreference.rawValue
        entity.selectedThemeID = theme.selectedThemeID
        entity.customThemesData = encodedCustomThemesData()
        entity.isActive = true
        entity.sourceRaw = TierListSource.authored.rawValue
        entity.externalIdentifier = draft.projectId.uuidString
        entity.iconSystemName = entity.iconSystemName ?? "square.and.pencil"

        entity.tiers.forEach { modelContext.delete($0) }
        entity.tiers.removeAll()
        entity.tiers = buildTierEntities(for: draft, listEntity: entity)
    }

    private func createTierListEntity(
        from draft: TierProjectDraft,
        projectData: Data,
        now: Date
    ) -> TierListEntity {
        TierListEntity(
            identifier: draft.projectId,
            title: draft.title.isEmpty ? "Untitled Project" : draft.title,
            fileName: nil,
            createdAt: draft.audit?.createdAt ?? now,
            updatedAt: now,
            isActive: true,
            cardDensityRaw: cardDensityPreference.rawValue,
            selectedThemeID: theme.selectedThemeID,
            customThemesData: encodedCustomThemesData(),
            sourceRaw: TierListSource.authored.rawValue,
            externalIdentifier: draft.projectId.uuidString,
            subtitle: draft.summary.isEmpty ? nil : draft.summary,
            iconSystemName: "square.and.pencil",
            lastOpenedAt: now,
            projectData: projectData,
            tiers: []
        )
    }

    private func buildTierEntities(for draft: TierProjectDraft, listEntity: TierListEntity) -> [TierEntity] {
        var rankedTiers = orderedTiers(for: draft).enumerated().map { index, tierDraft in
            buildTierEntity(from: tierDraft, index: index, listEntity: listEntity)
        }

        if let unranked = buildUnrankedTier(for: draft, order: rankedTiers.count, listEntity: listEntity) {
            rankedTiers.append(unranked)
        }

        return rankedTiers
    }

    private func buildTierEntity(
        from tierDraft: TierDraftTier,
        index: Int,
        listEntity: TierListEntity
    ) -> TierEntity {
        let tierEntity = TierEntity(
            key: normalizedTierKey(tierDraft.tierId),
            displayName: tierDraft.label,
            colorHex: tierDraft.colorHex,
            order: index,
            isLocked: tierDraft.locked,
            items: []
        )
        tierEntity.list = listEntity

        let items = orderedItems(for: tierDraft)
        for (position, draftItem) in items.enumerated() {
            let resolved = makeTierItemEntity(from: draftItem, position: position, tier: tierEntity)
            tierEntity.items.append(resolved)
        }

        return tierEntity
    }

    private func buildUnrankedTier(
        for draft: TierProjectDraft,
        order: Int,
        listEntity: TierListEntity
    ) -> TierEntity? {
        let unassigned = draft.items.filter { $0.tier == nil }
        guard !unassigned.isEmpty else { return nil }

        let unranked = TierEntity(
            key: "unranked",
            displayName: "Unranked",
            colorHex: "#6B7280",
            order: order,
            isLocked: false,
            items: []
        )
        unranked.list = listEntity

        for (position, item) in unassigned.enumerated() {
            let resolved = makeTierItemEntity(from: item, position: position, tier: unranked)
            unranked.items.append(resolved)
        }

        return unranked
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

    func buildProject(from draft: TierProjectDraft) throws -> Project {
        let tiers = buildTiersFromDraft(draft)
        let items = buildItemsFromDraft(draft)
        let overrides = buildOverridesFromDraft(draft)
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

    private func buildTiersFromDraft(_ draft: TierProjectDraft) -> [Project.Tier] {
        orderedTiers(for: draft).map { tier -> Project.Tier in
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
    }

    private func buildItemsFromDraft(_ draft: TierProjectDraft) -> [String: Project.Item] {
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
        return items
    }

    private func buildOverridesFromDraft(_ draft: TierProjectDraft) -> [String: Project.ItemOverride] {
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
        return overrides
    }

    func normalizeTierOrdering(for draft: TierProjectDraft) {
        for (index, tier) in orderedTiers(for: draft).enumerated() {
            tier.order = index
        }
    }

    func project(from entity: TierListEntity, source: TierListSource) -> Project {
        let sortedTiers = entity.tiers.sorted { $0.order < $1.order }
        let (itemMap, projectTiers) = buildProjectComponents(sortedTiers: sortedTiers)
        let settings = buildProjectSettingsFromEntity(entity, projectTiers: projectTiers)
        let storageMode = determineStorageMode(source: source)
        let audit = buildProjectAuditFromEntity(entity)

        return Project(
            schemaVersion: 1,
            projectId: entity.identifier.uuidString,
            title: entity.title,
            description: entity.subtitle,
            tiers: projectTiers,
            items: itemMap,
            overrides: nil,
            links: nil,
            storage: Project.Storage(mode: storageMode),
            settings: settings,
            collab: nil,
            audit: audit,
            additional: nil
        )
    }

    private func buildProjectComponents(
        sortedTiers: [TierEntity]
    ) -> ([String: Project.Item], [Project.Tier]) {
        var itemMap: [String: Project.Item] = [:]
        var projectTiers: [Project.Tier] = []

        for tierEntity in sortedTiers {
            let sortedItems = tierEntity.items.sorted { $0.position < $1.position }
            let identifiers = sortedItems.map(\.itemID)

            let tier = Project.Tier(
                id: tierEntity.key,
                label: tierEntity.displayName,
                color: tierEntity.colorHex,
                order: tierEntity.order,
                locked: tierEntity.isLocked ? true : nil,
                collapsed: nil,
                rules: nil,
                itemIds: identifiers,
                additional: nil
            )
            projectTiers.append(tier)

            for itemEntity in sortedItems where itemMap[itemEntity.itemID] == nil {
                let item = buildProjectItemFromEntity(itemEntity)
                itemMap[itemEntity.itemID] = item
            }
        }

        return (itemMap, projectTiers)
    }

    private func buildProjectItemFromEntity(_ itemEntity: TierItemEntity) -> Project.Item {
        var attributes: [String: JSONValue] = [:]
        if let season = itemEntity.seasonString {
            attributes["season"] = .string(season)
        }
        if let seasonNumber = itemEntity.seasonNumber {
            attributes["seasonNumber"] = .number(Double(seasonNumber))
        }
        if let status = itemEntity.status {
            attributes["status"] = .string(status)
        }
        if let image = itemEntity.imageUrl {
            attributes["imageUrl"] = .string(image)
        }

        return Project.Item(
            id: itemEntity.itemID,
            title: itemEntity.name ?? itemEntity.itemID,
            subtitle: nil,
            summary: itemEntity.details,
            slug: itemEntity.itemID,
            media: nil,
            attributes: attributes.isEmpty ? nil : attributes,
            tags: nil,
            rating: nil,
            sources: nil,
            locale: nil,
            meta: nil,
            additional: nil
        )
    }

    private func buildProjectSettingsFromEntity(
        _ entity: TierListEntity,
        projectTiers: [Project.Tier]
    ) -> Project.Settings {
        let hasUnranked = projectTiers.contains { $0.id.lowercased() == "unranked" }
        let themeSlug = entity.selectedThemeID.flatMap { TierThemeCatalog.theme(id: $0)?.slug }

        return Project.Settings(
            theme: themeSlug,
            tierSortOrder: "descending",
            gridSnap: true,
            showUnranked: hasUnranked,
            accessibility: [
                "voiceOver": true,
                "highContrast": false
            ]
        )
    }

    private func determineStorageMode(source: TierListSource) -> String {
        switch source {
        case .bundled:
            return "bundled"
        case .file:
            return "file"
        case .authored:
            return "local"
        }
    }

    private func buildProjectAuditFromEntity(_ entity: TierListEntity) -> Project.Audit {
        Project.Audit(
            createdAt: entity.createdAt,
            updatedAt: entity.updatedAt,
            createdBy: nil,
            updatedBy: nil
        )
    }

    func projectFromInMemoryState(source: TierListSource) -> Project {
        let orderedTiers = buildOrderedTiersIncludingUnranked()
        let (projectTiers, projectItems) = buildProjectTiersAndItems(orderedTiers: orderedTiers)
        let settings = buildInMemoryProjectSettings()
        let audit = buildInMemoryProjectAudit()
        let projectIdentifier = determineProjectIdentifier()

        return Project(
            schemaVersion: 1,
            projectId: projectIdentifier,
            title: persistence.activeTierList?.displayName ?? "Untitled Project",
            description: nil,
            tiers: projectTiers,
            items: projectItems,
            overrides: nil,
            links: nil,
            storage: Project.Storage(mode: source.rawValue),
            settings: settings,
            collab: nil,
            audit: audit,
            additional: nil
        )
    }

    private func buildOrderedTiersIncludingUnranked() -> [String] {
        var orderedTiers = tierOrder
        if tiers["unranked"].map({ !$0.isEmpty }) ?? false {
            orderedTiers.append("unranked")
        }
        return orderedTiers
    }

    private func buildProjectTiersAndItems(
        orderedTiers: [String]
    ) -> ([Project.Tier], [String: Project.Item]) {
        var projectTiers: [Project.Tier] = []
        var projectItems: [String: Project.Item] = [:]

        for (index, tierId) in orderedTiers.enumerated() {
            let resolvedItems = tiers[tierId] ?? []
            let tier = buildProjectTierFromMemory(
                tierId: tierId,
                index: index,
                items: resolvedItems
            )
            projectTiers.append(tier)

            for item in resolvedItems where projectItems[item.id] == nil {
                let projectItem = buildProjectItemFromMemory(item)
                projectItems[item.id] = projectItem
            }
        }

        return (projectTiers, projectItems)
    }

    private func buildProjectTierFromMemory(
        tierId: String,
        index: Int,
        items: [Item]
    ) -> Project.Tier {
        let label = tierLabels[tierId] ?? tierId
        let color = tierColors[tierId]
        let locked = lockedTiers.contains(tierId) ? true : nil
        let identifiers = items.map(\.id)

        return Project.Tier(
            id: tierId,
            label: label,
            color: color,
            order: index,
            locked: locked,
            collapsed: nil,
            rules: nil,
            itemIds: identifiers,
            additional: nil
        )
    }

    private func buildProjectItemFromMemory(_ item: Item) -> Project.Item {
        var attributes: [String: JSONValue] = [:]
        if let season = item.seasonString {
            attributes["season"] = .string(season)
        }
        if let seasonNumber = item.seasonNumber {
            attributes["seasonNumber"] = .number(Double(seasonNumber))
        }
        if let status = item.status {
            attributes["status"] = .string(status)
        }
        if let imageUrl = item.imageUrl {
            attributes["imageUrl"] = .string(imageUrl)
        }
        if let description = item.description {
            attributes["description"] = .string(description)
        }

        return Project.Item(
            id: item.id,
            title: item.name ?? item.id,
            subtitle: nil,
            summary: item.description,
            slug: item.id,
            media: nil,
            attributes: attributes.isEmpty ? nil : attributes,
            tags: nil,
            rating: nil,
            sources: nil,
            locale: nil,
            meta: nil,
            additional: nil
        )
    }

    private func buildInMemoryProjectSettings() -> Project.Settings {
        let themeSlug = TierThemeCatalog.theme(id: theme.selectedThemeID)?.slug
        return Project.Settings(
            theme: themeSlug,
            tierSortOrder: "descending",
            gridSnap: true,
            showUnranked: tiers["unranked"].map { !$0.isEmpty } ?? false,
            accessibility: [
                "voiceOver": true,
                "highContrast": false
            ]
        )
    }

    private func buildInMemoryProjectAudit() -> Project.Audit {
        Project.Audit(
            createdAt: Date(),
            updatedAt: Date(),
            createdBy: "local-user",
            updatedBy: "local-user"
        )
    }

    private func determineProjectIdentifier() -> String {
        persistence.activeTierList?.entityID?.uuidString
            ?? persistence.activeTierList?.identifier
            ?? UUID().uuidString
    }
}

internal enum TierListCreatorPalette {
    private static let colors: [String] = [
        "#FF3B30", "#FF9500", "#FFCC00", "#34C759", "#007AFF", "#AF52DE",
        "#FF2D55", "#5AC8FA", "#FF9F0A", "#FFD60A"
    ]

    static func color(for index: Int) -> String {
        guard index >= 0 else { return colors.first ?? "#FF3B30" }
        return colors[index % colors.count]
    }
}
