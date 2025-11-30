import Foundation
import Testing
@testable import TiercadeCore

@Suite("Models")
struct ModelsTests {
    @Test("Item decodes season values from string and number")
    func itemDecodingHandlesFlexibleSeason() throws {
        let json = """
        [
            { "id": "alpha", "season": "5" },
            { "id": "beta", "season": 6 }
        ]
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode([Item].self, from: json)
        #expect(decoded[0].seasonString == "5")
        #expect(decoded[0].seasonNumber == 5)
        #expect(decoded[1].seasonString == "6")
        #expect(decoded[1].seasonNumber == 6)
    }

    @Test("ModelResolver normalizes JSONValue when building attributes")
    func jsonValueNormalizationViaModelResolver() throws {
        let item = Project.Item(id: "alpha", title: "Alpha")
        let override = Project.ItemOverride(
            displayTitle: nil,
            notes: nil,
            tags: nil,
            rating: nil,
            media: nil,
            hidden: nil,
            additional: ["season": .number(7.0)],
        )

        let project = Project(
            schemaVersion: 1,
            projectId: "test",
            tiers: [Project.Tier(
                id: "S",
                label: "S",
                color: nil,
                order: 0,
                locked: nil,
                collapsed: nil,
                rules: nil,
                itemIds: ["alpha"],
            )],
            items: ["alpha": item],
            overrides: ["alpha": override],
            audit: Project.Audit(createdAt: .distantPast, updatedAt: .distantPast),
        )

        let resolved = ModelResolver.resolveTiers(from: project)
        let resolvedItem = try #require(resolved.first?.items.first)
        #expect(resolvedItem.attributes?["season"] == "7")
    }
}
