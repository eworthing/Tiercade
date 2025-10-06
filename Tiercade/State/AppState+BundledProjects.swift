import Foundation
import TiercadeCore

@MainActor
extension AppState {
    func applyBundledProject(_ bundled: BundledProject) {
        let state = resolvedTierState(for: bundled)
        tierOrder = state.order
        tiers = state.items
        tierLabels = state.labels
        tierColors = state.colors
        lockedTiers = state.locked
        history = HistoryLogic.initHistory(tiers, limit: history.limit)
        markAsChanged()
        currentFileName = bundled.id
        showSuccessToast("Loaded \(bundled.title)", message: "Bundled tier list ready to rank")
        let counts = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        logEvent("applyBundledProject id=\(bundled.id) counts=\(counts)")
        registerTierListSelection(TierListHandle(bundled: bundled))
    }
}

private extension AppState {
    struct BundledTierState {
        var order: [String]
        var items: Items
        var labels: [String: String]
        var colors: [String: String]
        var locked: Set<String>
    }

    func resolvedTierState(for bundled: BundledProject) -> BundledTierState {
        var state = BundledTierState(
            order: [],
            items: [:],
            labels: [:],
            colors: [:],
            locked: []
        )

        let metadata = Dictionary(uniqueKeysWithValues: bundled.project.tiers.map { ($0.id, $0) })
        let resolvedTiers = ModelResolver.resolveTiers(from: bundled.project)

        populateState(with: resolvedTiers, metadata: metadata, state: &state)
        appendMissingTiers(from: bundled.project.tiers, state: &state)

        return state
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
}
