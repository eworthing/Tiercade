import Foundation
import TiercadeCore

@MainActor
extension AppState {
    func presentBundledTierlists() {
        showingBundledSelector = true
        logEvent("bundledSelector: presented")
    }

    func dismissBundledTierlists() {
        guard showingBundledSelector else { return }
        showingBundledSelector = false
        logEvent("bundledSelector: dismissed")
    }

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
        showingBundledSelector = false
        showSuccessToast("Loaded \(bundled.title)", message: "Bundled tier list ready to rank")
        let counts = tierOrder
            .map { "\($0):\(tiers[$0]?.count ?? 0)" }
            .joined(separator: ", ")
        logEvent("applyBundledProject id=\(bundled.id) counts=\(counts)")
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
            order.append(resolved.label)
            if let tier = metadata[resolved.id] {
                labels[resolved.label] = tier.label
                if let color = tier.color { colors[resolved.label] = color }
                if let isLocked = tier.locked, isLocked { locked.insert(resolved.label) }
            }
            items[resolved.label] = resolved.items.map { item in
                Item(
                    id: item.id,
                    name: item.title,
                    status: nil,
                    description: item.description,
                    imageUrl: item.thumbUri
                )
            }
        }

        for tier in bundled.project.tiers where items[tier.label] == nil {
            order.append(tier.label)
            items[tier.label] = []
            labels[tier.label] = tier.label
            if let color = tier.color { colors[tier.label] = color }
            if let isLocked = tier.locked, isLocked { locked.insert(tier.label) }
        }

        return BundledTierState(order: order, items: items, labels: labels, colors: colors, locked: locked)
    }
}
