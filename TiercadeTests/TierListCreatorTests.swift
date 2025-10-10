import Testing
@testable import Tiercade

@Suite("Tier list creator")
@MainActor
struct TierListCreatorTests {
    @Test("Presenting the creator seeds a default draft")
    func presentingSeedsDraft() {
        let app = AppState(inMemory: true)
        defer { clearPersistedState() }

        app.presentTierListCreator()

        #expect(app.showTierListCreator)
        #expect(app.tierListCreatorDraft != nil)
        #expect(app.tierListCreatorDraft?.tiers.isEmpty == false)
    }

    @Test("Validation catches missing title and tiers")
    func validationGuardsRequiredFields() {
        let app = AppState(inMemory: true)
        defer { clearPersistedState() }

        app.presentTierListCreator()
        guard let draft = app.tierListCreatorDraft else {
            Issue.record("Draft should be created when presenting")
            return
        }

        draft.title = ""
        draft.tiers.removeAll()

        let issues = app.validateTierListDraft()

        #expect(!issues.isEmpty)
        #expect(issues.contains { $0.category == .project })
        #expect(issues.contains { $0.category == .tier })
    }

    @Test("Saving a draft persists an authored entity")
    func saveDraftPersistsEntity() async {
        let app = AppState(inMemory: true)
        defer { clearPersistedState() }

        app.presentTierListCreator()
        guard let draft = app.tierListCreatorDraft else {
            Issue.record("Draft should be created when presenting")
            return
        }

        draft.title = "Test Draft"
        if let tier = app.orderedTiers(for: draft).first {
            let item = app.addItem(to: draft)
            item.title = "Sample Item"
            item.itemId = "sample-item"
            app.assign(item, to: tier, in: draft)
        }

        await app.saveTierListDraft(action: .save)

        #expect(app.showTierListCreator == false)
        #expect(app.activeTierList?.source == .authored)
        #expect(app.recentTierLists.contains { $0.source == .authored })
    }

    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: "Tiercade.tierlist.active.v1")
        UserDefaults.standard.removeObject(forKey: "Tiercade.tierlist.recents.v1")
    }
}
