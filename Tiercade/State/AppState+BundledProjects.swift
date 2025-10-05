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
        var items: Items = [:]
        var order: [String] = []
        var labels: [String: String] = [:]
        var colors: [String: String] = [:]
        var locked: Set<String> = []

        let metadata = Dictionary(uniqueKeysWithValues: bundled.project.tiers.map { ($0.id, $0) })
        let resolvedTiers = ModelResolver.resolveTiers(from: bundled.project)

        for resolved in resolvedTiers {
            // Normalize tier name: "Unranked" -> "unranked"
            let normalizedLabel = normalizeTierName(resolved.label)

            // Skip unranked - it's handled separately, not part of tierOrder
            if normalizedLabel != "unranked" {
                order.append(normalizedLabel)
            }

            if let tier = metadata[resolved.id] {
                labels[normalizedLabel] = tier.label
                if let color = tier.color { colors[normalizedLabel] = color }
                if let isLocked = tier.locked, isLocked { locked.insert(normalizedLabel) }
            }
            items[normalizedLabel] = resolved.items.map { item in
                Item(
                    id: item.id,
                    name: item.title,
                    status: nil,
                    description: item.description,
                    imageUrl: item.thumbUri
                )
            }
        }

        for tier in bundled.project.tiers where items[normalizeTierName(tier.label)] == nil {
            let normalizedLabel = normalizeTierName(tier.label)

            // Skip unranked - it's handled separately, not part of tierOrder
            if normalizedLabel != "unranked" {
                order.append(normalizedLabel)
            }

            items[normalizedLabel] = []
            labels[normalizedLabel] = tier.label
            if let color = tier.color { colors[normalizedLabel] = color }
            if let isLocked = tier.locked, isLocked { locked.insert(normalizedLabel) }
        }

        return BundledTierState(order: order, items: items, labels: labels, colors: colors, locked: locked)
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
