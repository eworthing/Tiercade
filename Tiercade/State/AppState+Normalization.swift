import Foundation
import TiercadeCore

@MainActor
extension AppState {
    /// Ensure every item has canonical properties populated.
    static func normalizedTiers(from tiers: Items) -> Items {
        var normalized: Items = [:]
        for (tier, items) in tiers {
            normalized[tier] = items.map { item in
                Item(
                    id: item.id,
                    name: item.name,
                    seasonString: item.seasonString,
                    seasonNumber: item.seasonNumber,
                    status: item.status,
                    description: item.description,
                    imageUrl: item.imageUrl,
                    videoUrl: item.videoUrl
                )
            }
        }
        return normalized
    }
}
