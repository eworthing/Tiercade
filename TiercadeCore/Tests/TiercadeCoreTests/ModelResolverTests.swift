import XCTest
@testable import TiercadeCore

final class ModelResolverTests: XCTestCase {
    func testResolveTiers_basic() {
        // Build a minimal project dict
        let itemA: [String: Any] = ["title": "Alpha", "media": [["thumbUri": "http://example.com/a.jpg"]], "season": "1"]
        let itemB: [String: Any] = ["title": "Beta", "posterUri": "http://example.com/b.jpg", "season": 2]
        let items: [String: Any] = ["a": itemA, "b": itemB]

        let tier1: [String: Any] = ["id": "t1", "label": "Group 1", "itemIds": ["a"]]
        let tier2: [String: Any] = ["id": "t2", "label": "Group 2", "itemIds": ["b"]]

        let project: [String: Any] = ["tiers": [tier1, tier2], "items": items]

        let resolved = ModelResolver.resolveTiers(from: project)
        XCTAssertEqual(resolved.count, 2)
        XCTAssertEqual(resolved[0].label, "Group 1")
        XCTAssertEqual(resolved[0].items.first?.title, "Alpha")
        XCTAssertEqual(resolved[1].items.first?.title, "Beta")
        XCTAssertEqual(resolved[0].items.first?.attributes?["thumbUri"], "http://example.com/a.jpg")
    }
}
