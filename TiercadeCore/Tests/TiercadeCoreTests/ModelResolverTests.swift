import Foundation
import Testing
@testable import TiercadeCore

// MARK: - ModelResolverTests

@Suite("ModelResolver")
struct ModelResolverTests {
    @Test("decodeProject validates offline manifests")
    func decodeProjectRespectsValidation() throws {
        let data = try ModelResolverTests.sampleProjectData()
        let project = try ModelResolver.decodeProject(from: data)
        #expect(project.schemaVersion == 1)
        #expect(project.items["alpha"]?.title == "Alpha")
    }

    @Test("decodeProjectAsync matches synchronous decode")
    func asyncDecodeMatches() async throws {
        let data = try ModelResolverTests.sampleProjectData()
        let sync = try ModelResolver.decodeProject(from: data)
        let async = try await ModelResolver.decodeProjectAsync(from: data)
        #expect(sync == async)
    }

    @Test("resolveTiers applies overrides and derives attributes")
    func resolveTiersAppliesOverrides() throws {
        let project = ModelResolverTests.sampleProject()
        let tiers = ModelResolver.resolveTiers(from: project)

        #expect(tiers.count == 2)
        let sTier = try #require(tiers.first(where: { $0.label == "S" }))
        let unranked = try #require(tiers.first(where: { $0.label == "Unranked" }))

        let overriden = try #require(sTier.items.first(where: { $0.id == "alpha" }))
        #expect(overriden.title == "Alpha Deluxe")
        #expect(overriden.description == "Override notes")
        #expect(overriden.thumbUri == "file://override-thumb.png")
        #expect(overriden.attributes?["name"] == "Alpha Deluxe")
        #expect(overriden.attributes?["rating"] == "4.5")

        let fallback = try #require(unranked.items.first(where: { $0.id == "beta" }))
        #expect(fallback.title == "Beta")
        #expect(fallback.thumbUri == "file://base-thumb.png")
    }
}

extension ModelResolverTests {
    fileprivate static func sampleProject() -> Project {
        let audit = Project.Audit(
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
        )

        let baseMedia = Project.Media(
            id: "m-base",
            kind: .image,
            uri: "file://base.png",
            mime: "image/png",
            thumbUri: "file://base-thumb.png",
        )

        let overrideMedia = Project.Media(
            id: "m-override",
            kind: .image,
            uri: "file://override.png",
            mime: "image/png",
            thumbUri: "file://override-thumb.png",
        )

        let items: [String: Project.Item] = [
            "alpha": Project.Item(
                id: "alpha",
                title: "Alpha",
                summary: "Base summary",
                media: [baseMedia],
                rating: 3.0,
            ),
            "beta": Project.Item(
                id: "beta",
                title: "Beta",
                media: [baseMedia],
            ),
        ]

        let overrides: [String: Project.ItemOverride] = [
            "alpha": Project.ItemOverride(
                displayTitle: "Alpha Deluxe",
                notes: "Override notes",
                rating: 4.5,
                media: [overrideMedia],
                additional: ["season": .string("2")],
            ),
        ]

        let tiers: [Project.Tier] = [
            Project.Tier(
                id: "tier-s",
                label: "S",
                color: "#FFD700",
                order: 0,
                itemIds: ["alpha"],
            ),
            Project.Tier(
                id: "tier-unranked",
                label: "Unranked",
                order: 1,
                itemIds: ["beta"],
            ),
        ]

        return Project(
            schemaVersion: 1,
            projectId: "project-1",
            title: "Sample",
            tiers: tiers,
            items: items,
            overrides: overrides,
            storage: .init(mode: "local"),
            audit: audit,
        )
    }

    fileprivate static func sampleProjectData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(sampleProject())
    }
}
