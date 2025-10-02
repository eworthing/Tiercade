import Testing
import Foundation
@testable import Tiercade

@Suite("Tier list switching")
@MainActor
struct TierListSwitcherTests {
    @Test("Quick picks prioritize active handle")
    func quickPicksPrioritizeActive() {
        let app = AppState()
        defer { clearPersistedState() }

        let active = AppState.TierListHandle(
            source: .file,
            identifier: "local-session",
            displayName: "Local Session",
            subtitle: "Unsaved",
            iconSystemName: "doc.text"
        )
        let recentBundled = AppState.TierListHandle(
            source: .bundled,
            identifier: "star-wars-saga",
            displayName: "Star Wars Films",
            subtitle: "Bundled",
            iconSystemName: "square.grid.2x2"
        )

        app.activeTierList = active
        app.recentTierLists = [recentBundled]

        let picks = app.quickPickTierLists

        #expect(!picks.isEmpty)
        #expect(picks.first == active)
        #expect(picks.contains(recentBundled))
    }

    @Test("Register selection moves handle to front")
    func registerSelectionUpdatesRecents() {
        let app = AppState()
        defer { clearPersistedState() }

        let initial = AppState.TierListHandle(
            source: .file,
            identifier: "previous",
            displayName: "Previous",
            subtitle: nil,
            iconSystemName: nil
        )
        app.recentTierLists = [initial]

        let selected = AppState.TierListHandle(
            source: .bundled,
            identifier: "survivor-legends",
            displayName: "Survivor Winners",
            subtitle: "Bundled",
            iconSystemName: "square.grid.2x2"
        )

        app.registerTierListSelection(selected)

        #expect(app.activeTierList == selected)
        #expect(app.recentTierLists.first == selected)
        #expect(app.recentTierLists.contains(initial))
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: "Tiercade.tierlist.active.v1")
        UserDefaults.standard.removeObject(forKey: "Tiercade.tierlist.recents.v1")
    }
}
