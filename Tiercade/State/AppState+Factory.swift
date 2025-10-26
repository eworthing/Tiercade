import SwiftData

internal extension AppState {
    /// Convenience initializer used by previews and tests to spin up an in-memory store.
    /// Default behaviour mirrors the production container but avoids disk persistence.
    @MainActor
    convenience init(inMemory: Bool = true) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        let container: ModelContainer
        do {
            container = try ModelContainer(
                for: TierListEntity.self,
                TierEntity.self,
                TierItemEntity.self,
                TierThemeEntity.self,
                TierColorEntity.self,
                TierProjectDraft.self,
                TierDraftTier.self,
                TierDraftItem.self,
                TierDraftOverride.self,
                TierDraftMedia.self,
                TierDraftAudit.self,
                TierDraftCollabMember.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to create in-memory model container: \(error)")
        }
        self.init(modelContext: container.mainContext)
    }
}
