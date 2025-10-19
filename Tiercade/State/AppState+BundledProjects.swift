import Foundation
import SwiftData
import os
import TiercadeCore

@MainActor
extension AppState {
    func applyBundledProject(_ bundled: BundledProject) {
        let snapshot = captureTierSnapshot()
        let state = resolvedTierState(from: bundled.project)
        tierOrder = state.order
        tiers = state.items
        tierLabels = state.labels
        tierColors = state.colors
        lockedTiers = state.locked
        finalizeChange(action: "Load Bundled Project", undoSnapshot: snapshot)
        currentFileName = bundled.id
        showSuccessToast("Loaded \(bundled.title)", message: "Bundled tier list ready to rank")
        let counts = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        logEvent("applyBundledProject id=\(bundled.id) counts=\(counts)")
        registerTierListSelection(TierListHandle(bundled: bundled))
    }
}

extension AppState {
    struct BundledTierState {
        var order: [String]
        var items: Items
        var labels: [String: String]
        var colors: [String: String]
        var locked: Set<String>
    }

    func resolvedTierState(from project: Project) -> BundledTierState {
        var state = BundledTierState(
            order: [],
            items: [:],
            labels: [:],
            colors: [:],
            locked: []
        )

        let metadata = Dictionary(uniqueKeysWithValues: project.tiers.map { ($0.id, $0) })
        let resolvedTiers = ModelResolver.resolveTiers(from: project)

        populateState(with: resolvedTiers, metadata: metadata, state: &state)
        appendMissingTiers(from: project.tiers, state: &state)

        return state
    }

    func resolvedTierState(for bundled: BundledProject) -> BundledTierState {
        resolvedTierState(from: bundled.project)
    }

    func populateState(
        with resolvedTiers: [ResolvedTier],
        metadata: [String: Project.Tier],
        state: inout BundledTierState
    ) {
        for resolved in resolvedTiers {
            let normalizedLabel = normalizeTierName(resolved.label)
            appendTierToOrderIfNeeded(normalizedLabel, order: &state.order)
            applyTierMetadata(metadata[resolved.id], normalizedLabel: normalizedLabel, state: &state)
            state.items[normalizedLabel] = resolved.items.map(makeItem)
        }
    }

    func appendMissingTiers(from tiers: [Project.Tier], state: inout BundledTierState) {
        for tier in tiers {
            let normalizedLabel = normalizeTierName(tier.label)
            guard state.items[normalizedLabel] == nil else { continue }
            appendTierToOrderIfNeeded(normalizedLabel, order: &state.order)
            state.items[normalizedLabel] = []
            state.labels[normalizedLabel] = tier.label
            if let color = tier.color { state.colors[normalizedLabel] = color }
            if tier.locked == true { state.locked.insert(normalizedLabel) }
        }
    }

    func appendTierToOrderIfNeeded(_ normalizedLabel: String, order: inout [String]) {
        guard normalizedLabel != "unranked" else { return }
        if !order.contains(normalizedLabel) {
            order.append(normalizedLabel)
        }
    }

    func applyTierMetadata(
        _ tier: Project.Tier?,
        normalizedLabel: String,
        state: inout BundledTierState
    ) {
        guard let tier else { return }
        state.labels[normalizedLabel] = tier.label
        if let color = tier.color { state.colors[normalizedLabel] = color }
        if tier.locked == true { state.locked.insert(normalizedLabel) }
    }

    func makeItem(from entry: ResolvedItem) -> Item {
        Item(
            id: entry.id,
            name: entry.title,
            status: nil,
            description: entry.description,
            imageUrl: entry.thumbUri
        )
    }

    /// Normalize tier names to lowercase for consistency
    /// "Unranked" -> "unranked", "UNRANKED" -> "unranked", etc.
    func normalizeTierName(_ name: String) -> String {
        // Special case: normalize any variant of "unranked" to lowercase
        if name.lowercased() == "unranked" {
            return "unranked"
        }
        // Keep other tier names as-is (S, A, B, C, D, F, etc.)
        return name
    }

    func prefillBundledProjectsIfNeeded() {
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
        let encodedProject = try? TierListCreatorCodec.makeEncoder().encode(project.project)
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
            projectData: encodedProject,
            tiers: []
        )

        let metadata = Dictionary(uniqueKeysWithValues: project.project.tiers.map { ($0.id, $0) })
        let resolvedTiers = ModelResolver.resolveTiers(from: project.project)

        for (index, resolvedTier) in resolvedTiers.enumerated() {
            let tierEntity = createTierEntity(
                from: resolvedTier,
                index: index,
                totalTiers: resolvedTiers.count,
                metadata: metadata,
                listEntity: entity
            )
            entity.tiers.append(tierEntity)
        }

        return entity
    }

    private func createTierEntity(
        from resolvedTier: ResolvedTier,
        index: Int,
        totalTiers: Int,
        metadata: [String: Project.Tier],
        listEntity: TierListEntity
    ) -> TierEntity {
        let normalizedKey = normalizeTierName(resolvedTier.label)
        let tierMetadata = metadata[resolvedTier.id]
        let order = normalizedKey == "unranked" ? totalTiers : index
        let tierEntity = TierEntity(
            key: normalizedKey,
            displayName: resolvedTier.label,
            colorHex: tierMetadata?.color,
            order: order,
            isLocked: tierMetadata?.locked ?? false
        )
        tierEntity.list = listEntity

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

        return tierEntity
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
}
