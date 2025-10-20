import Foundation
import Testing
@testable import TiercadeCore

@Suite("DataLoader")
struct DataLoaderTests {
    @Test("Decodes items and groups and validates relationships")
    func decodeAndValidate() throws {
        let loader = DataLoader()
        let itemsJSON = """
        {
            "alpha": { "id": "alpha", "name": "Alpha" },
            "beta": { "id": "beta", "name": "Beta" }
        }
        """.data(using: .utf8)!

        let groupsJSON = """
        {
            "favorites": ["alpha", "beta"]
        }
        """.data(using: .utf8)!

        let items = try loader.decodeItems(from: itemsJSON)
        let groups = try loader.decodeGroups(from: groupsJSON)

        #expect(items.count == 2)
        #expect(groups["favorites"]?.count == 2)
        #expect(loader.validate(groups: groups, items: items) == true)

        var invalidGroups = groups
        invalidGroups["favorites"] = ["alpha", "missing"]
        #expect(loader.validate(groups: invalidGroups, items: items) == false)
    }
}
