import SwiftUI
import TiercadeCore

@MainActor
internal enum PreviewFixtures {
    /// Base preview AppState with an in-memory store and default seed applied.
    /// You can customize the state further in previews if needed.
    static func makeBaseAppState() -> AppState {
        AppState(inMemory: true)
    }

    /// AppState seeded with a simple "sample items" scenario across common tiers.
    ///
    /// - Creates a small number of items and distributes them across S/A/B and unranked.
    /// - Leaves undo/history empty so previews remain lightweight.
    /// - Uses canonical tier order ["S", "A", "B", "C", "D", "F"] per AGENTS.md contract.
    static func makeSampleTierAppState() -> AppState {
        let app = AppState(inMemory: true)

        // Clear any seeded tiers and start from the default TierListState structure.
        // Canonical tier contract: ["S","A","B","C","D","F","unranked"]
        app.tiers = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], TierIdentifier.unranked.rawValue: []]
        app.tierOrder = ["S", "A", "B", "C", "D", "F"]
        app.tierLabels = ["S": "Top Picks", "A": "Great", "B": "Good", "C": "Decent", "D": "Meh", "F": "Worst"]

        let items: [Item] = [
            Item(id: "preview-1", name: "Sample Hero", status: nil, description: "A standout item in S tier.", imageUrl: nil),
            Item(id: "preview-2", name: "Solid Choice", status: nil, description: "Reliable A‑tier item.", imageUrl: nil),
            Item(id: "preview-3", name: "Pretty Good", status: nil, description: "Comfortable B‑tier item.", imageUrl: nil),
            Item(id: "preview-4", name: "Unranked Candidate", status: nil, description: "Waiting to be ranked.", imageUrl: nil)
        ]

        app.tiers["S"] = [items[0]]
        app.tiers["A"] = [items[1]]
        app.tiers["B"] = [items[2]]
        app.tiers[TierIdentifier.unranked.rawValue] = [items[3]]

        app.selection = []
        app.globalSortMode = .alphabetical(ascending: true)

        return app
    }
}

@MainActor
internal enum PreviewHelpers {
    /// Create an in-memory AppState suitable for SwiftUI previews.
    /// Uses `PreviewFixtures.makeSampleTierAppState()` by default, then applies
    /// any additional overlay-specific configuration.
    static func makeAppState(configure: ((AppState) -> Void)? = nil) -> AppState {
        let state = PreviewFixtures.makeSampleTierAppState()
        configure?(state)
        return state
    }
}
