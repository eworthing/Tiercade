import XCTest
@testable import TiercadeCore

final class ModelResolverTests: XCTestCase {
    func testResolveTiers_basic() throws {
        let audit = Project.Audit(
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )

        let mediaA = Project.Media(
            id: "media-a",
            kind: .image,
            uri: "file:///tmp/a.jpg",
            mime: "image/jpeg",
            thumbUri: "file:///tmp/a_thumb.jpg"
        )

        let mediaB = Project.Media(
            id: "media-b",
            kind: .image,
            uri: "file:///tmp/b.jpg",
            mime: "image/jpeg",
            posterUri: "file:///tmp/b_poster.jpg"
        )

        let itemA = Project.Item(
            id: "a",
            title: "Alpha",
            media: [mediaA],
            attributes: ["season": .string("1")]
        )

        let itemB = Project.Item(
            id: "b",
            title: "Beta",
            media: [mediaB],
            attributes: ["season": .number(2)]
        )

        let tier1 = Project.Tier(id: "t1", label: "Group 1", order: 0, itemIds: ["a"])
        let tier2 = Project.Tier(id: "t2", label: "Group 2", order: 1, itemIds: ["b"])

        let project = Project(
            schemaVersion: 1,
            projectId: UUID().uuidString,
            tiers: [tier1, tier2],
            items: ["a": itemA, "b": itemB],
            audit: audit
        )

        let resolved = ModelResolver.resolveTiers(from: project)
        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved[0].label, "Group 1")
        XCTAssertEqual(resolved[0].items.first?.title, "Alpha")
        XCTAssertEqual(resolved[1].items.first?.title, "Beta")
        XCTAssertEqual(resolved[0].items.first?.attributes?["thumbUri"], "file:///tmp/a_thumb.jpg")
        XCTAssertEqual(resolved[1].items.first?.attributes?["thumbUri"], "file:///tmp/b_poster.jpg")
    }
}
