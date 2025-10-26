import Foundation
import TiercadeCore

@MainActor
internal extension AppState {
    // MARK: - Search & Filter
    internal func filteredItems(for tier: String) -> [Item] {
        var items = tiers[tier] ?? []

        switch activeFilter {
        case .all:
            break
        case .ranked:
            if tier == "unranked" { return [] }
        case .unranked:
            if tier != "unranked" { return [] }
        }

        items = applySearchFilter(to: items)
        return items
    }

    internal func allItems() -> [Item] {
        switch activeFilter {
        case .all:
            let all = tierOrder.flatMap { tiers[$0] ?? [] } + (tiers["unranked"] ?? [])
            return applySearchFilter(to: all)
        case .ranked:
            let ranked = tierOrder.flatMap { tiers[$0] ?? [] }
            return applySearchFilter(to: ranked)
        case .unranked:
            let unranked = tiers["unranked"] ?? []
            return applySearchFilter(to: unranked)
        }
    }

    internal func tierCount(_ tier: String) -> Int { tiers[tier]?.count ?? 0 }
    internal func rankedCount() -> Int { tierOrder.flatMap { tiers[$0] ?? [] }.count }
    internal func unrankedCount() -> Int { tiers["unranked"]?.count ?? 0 }
    internal func items(for tier: String) -> [Item] { tiers[tier] ?? [] }

    internal func applySearchFilter(to items: [Item]) -> [Item] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return items }

        if items.count > 50 {
            setSearchProcessing(true)
        }

        let filteredResults = items.filter { item in
            let name = (item.name ?? "").lowercased()
            let season = (item.seasonString ?? "").lowercased()
            let id = item.id.lowercased()

            return name.contains(query) || season.contains(query) || id.contains(query)
        }

        if items.count > 50 {
            setSearchProcessing(false)
        }

        return filteredResults
    }
}
