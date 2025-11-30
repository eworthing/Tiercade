import Foundation
import Testing
@testable import TiercadeCore

@Suite("Sorting Tests")
struct SortingTests {

    // MARK: - Alphabetical Sorting Tests

    @Test("Alphabetical A-Z sorts items by name using locale-aware comparison")
    func alphabeticalAscending() {
        let items = [
            Item(id: "3", name: "Zebra"),
            Item(id: "1", name: "Apple"),
            Item(id: "2", name: "banana"), // Test case-insensitive
            Item(id: "4", name: "cherry"),
        ]

        let sorted = Sorting.sortItems(items, by: .alphabetical(ascending: true))

        #expect(sorted.map(\.name) == ["Apple", "banana", "cherry", "Zebra"])
    }

    @Test("Alphabetical Z-A sorts items in reverse order")
    func alphabeticalDescending() {
        let items = [
            Item(id: "1", name: "Apple"),
            Item(id: "2", name: "Banana"),
            Item(id: "3", name: "Cherry"),
        ]

        let sorted = Sorting.sortItems(items, by: .alphabetical(ascending: false))

        #expect(sorted.map(\.name) == ["Cherry", "Banana", "Apple"])
    }

    @Test("Alphabetical sort falls back to ID for items without names")
    func alphabeticalWithMissingNames() {
        let items = [
            Item(id: "z-item", name: nil),
            Item(id: "a-item", name: "Apple"),
            Item(id: "m-item", name: nil),
        ]

        let sorted = Sorting.sortItems(items, by: .alphabetical(ascending: true))

        // Items with names sort by name, items without names sort by ID
        #expect(sorted[0].id == "a-item") // "Apple" comes first
        #expect(sorted[1].id == "m-item") // "m-item" ID
        #expect(sorted[2].id == "z-item") // "z-item" ID
    }

    @Test("Alphabetical sort is stable (preserves relative order for equal elements)")
    func alphabeticalStability() {
        let items = [
            Item(id: "first", name: "Apple"),
            Item(id: "second", name: "Apple"),
            Item(id: "third", name: "Apple"),
        ]

        let sorted = Sorting.sortItems(items, by: .alphabetical(ascending: true))

        // Tie-breaking should use name, then ID
        #expect(sorted.map(\.id) == ["first", "second", "third"])
    }

    // MARK: - Numeric Attribute Sorting Tests

    @Test("Sort by seasonNumber ascending")
    func numericAscending() {
        let items = [
            Item(id: "3", seasonNumber: 5),
            Item(id: "1", seasonNumber: 1),
            Item(id: "2", seasonNumber: 3),
        ]

        let sorted = Sorting.sortItems(items, by: .byAttribute(key: "seasonNumber", ascending: true, type: .number))

        #expect(sorted.map(\.seasonNumber) == [1, 3, 5])
    }

    @Test("Sort by seasonNumber descending")
    func numericDescending() {
        let items = [
            Item(id: "1", seasonNumber: 1),
            Item(id: "2", seasonNumber: 3),
            Item(id: "3", seasonNumber: 5),
        ]

        let sorted = Sorting.sortItems(items, by: .byAttribute(key: "seasonNumber", ascending: false, type: .number))

        #expect(sorted.map(\.seasonNumber) == [5, 3, 1])
    }

    @Test("Numeric sort handles nil values (sorts them last)")
    func numericWithNils() {
        let items = [
            Item(id: "3", seasonNumber: 5),
            Item(id: "nil1", name: "No Season 1", seasonNumber: nil),
            Item(id: "1", seasonNumber: 1),
            Item(id: "nil2", name: "No Season 2", seasonNumber: nil),
        ]

        let sorted = Sorting.sortItems(items, by: .byAttribute(key: "seasonNumber", ascending: true, type: .number))

        // Items with values come first, nils last
        #expect(sorted[0].seasonNumber == 1)
        #expect(sorted[1].seasonNumber == 5)
        #expect(sorted[2].seasonNumber == nil)
        #expect(sorted[3].seasonNumber == nil)
    }

    @Test("Numeric sort uses stable tiebreaker for equal numbers")
    func numericTiebreak() {
        let items = [
            Item(id: "second", name: "Beta", seasonNumber: 1),
            Item(id: "first", name: "Alpha", seasonNumber: 1),
            Item(id: "third", name: "Gamma", seasonNumber: 1),
        ]

        let sorted = Sorting.sortItems(items, by: .byAttribute(key: "seasonNumber", ascending: true, type: .number))

        // Tiebreak by name: Alpha < Beta < Gamma
        #expect(sorted.map(\.name) == ["Alpha", "Beta", "Gamma"])
    }

    // MARK: - String Attribute Sorting Tests

    @Test("Sort by status attribute")
    func stringAttribute() {
        let items = [
            Item(id: "1", status: "Watching"),
            Item(id: "2", status: "Completed"),
            Item(id: "3", status: "Plan to Watch"),
        ]

        let sorted = Sorting.sortItems(items, by: .byAttribute(key: "status", ascending: true, type: .string))

        #expect(sorted.map(\.status) == ["Completed", "Plan to Watch", "Watching"])
    }

    @Test("String attribute sort handles nil values")
    func stringAttributeWithNils() {
        let items = [
            Item(id: "2", name: "Item B", status: "Active"),
            Item(id: "3", name: "Item C", status: nil),
            Item(id: "1", name: "Item A", status: "Inactive"),
        ]

        let sorted = Sorting.sortItems(items, by: .byAttribute(key: "status", ascending: true, type: .string))

        // Nils sort last
        #expect(sorted[0].status == "Active")
        #expect(sorted[1].status == "Inactive")
        #expect(sorted[2].status == nil)
    }

    // MARK: - Custom Mode (No-Op) Tests

    @Test("Custom mode returns items in original order")
    func customModePreservesOrder() {
        let items = [
            Item(id: "3"),
            Item(id: "1"),
            Item(id: "2"),
        ]

        let sorted = Sorting.sortItems(items, by: .custom)

        #expect(sorted.map(\.id) == ["3", "1", "2"])
    }

    // MARK: - Attribute Discovery Tests

    @Test("Discover attributes present in ≥70% of items")
    func discoverCommonAttributes() {
        let items: Items = [
            "S": [
                Item(id: "1", name: "Item 1", status: "Active"),
                Item(id: "2", name: "Item 2", status: "Completed"),
                Item(id: "3", name: "Item 3", status: "Active"),
            ],
            "A": [
                Item(id: "4", name: "Item 4", status: "Inactive"),
                Item(id: "5", name: "Item 5"), // Missing status
            ],
        ]

        let discovered = Sorting.discoverSortableAttributes(in: items)

        // name: 5/5 = 100% ✓
        // status: 4/5 = 80% ✓
        #expect(discovered["name"] == .string)
        #expect(discovered["status"] == .string)
    }

    @Test("Attribute discovery respects 70% threshold")
    func discoverAttributeThreshold() {
        let items: Items = [
            "S": [
                Item(id: "1", name: "Item 1", status: "Active"),
                Item(id: "2", name: "Item 2", status: "Active"),
                Item(id: "3", name: "Item 3"), // No status
                Item(id: "4", name: "Item 4"), // No status
                Item(id: "5", name: "Item 5"), // No status
                Item(id: "6", name: "Item 6"), // No status
                Item(id: "7", name: "Item 7"), // No status
                Item(id: "8", name: "Item 8"), // No status
                Item(id: "9", name: "Item 9"), // No status
                Item(id: "10", name: "Item 10"), // No status
            ],
        ]

        let discovered = Sorting.discoverSortableAttributes(in: items)

        // name: 10/10 = 100% ✓
        // status: 2/10 = 20% ✗ (below 70% threshold)
        #expect(discovered["name"] == .string)
        #expect(discovered["status"] == nil)
    }

    @Test("Attribute discovery returns empty for empty tier collection")
    func discoverEmptyItems() {
        let items: Items = [:]
        let discovered = Sorting.discoverSortableAttributes(in: items)
        #expect(discovered.isEmpty)
    }

    @Test("Attribute discovery identifies multiple attribute types")
    func discoverMultipleTypes() {
        let items: Items = [
            "S": [
                Item(id: "1", name: "A", status: "Active", description: "First"),
                Item(id: "2", name: "B", status: "Inactive", description: "Second"),
                Item(id: "3", name: "C", status: "Pending", description: "Third"),
            ],
        ]

        let discovered = Sorting.discoverSortableAttributes(in: items)

        #expect(discovered["name"] == .string)
        #expect(discovered["status"] == .string)
        #expect(discovered["description"] == .string)
    }

    // MARK: - Edge Cases

    @Test("Sorting empty array returns empty array")
    func emptyArray() {
        let items: [Item] = []
        let sorted = Sorting.sortItems(items, by: .alphabetical(ascending: true))
        #expect(sorted.isEmpty)
    }

    @Test("Sorting single item returns single item")
    func singleItem() {
        let items = [Item(id: "1", name: "Only")]
        let sorted = Sorting.sortItems(items, by: .alphabetical(ascending: true))
        #expect(sorted.count == 1)
        #expect(sorted[0].id == "1")
    }

    // MARK: - GlobalSortMode Properties Tests

    @Test("GlobalSortMode displayName property returns correct strings")
    func displayNameProperty() {
        #expect(GlobalSortMode.custom.displayName == "Manual Order")
        #expect(GlobalSortMode.alphabetical(ascending: true).displayName == "A → Z")
        #expect(GlobalSortMode.alphabetical(ascending: false).displayName == "Z → A")
        #expect(GlobalSortMode.byAttribute(key: "status", ascending: true, type: .string).displayName == "Status ↑")
        #expect(GlobalSortMode.byAttribute(key: "description", ascending: false, type: .string)
            .displayName == "Description ↓")
    }

    @Test("GlobalSortMode isCustom property returns correct boolean")
    func isCustomProperty() {
        #expect(GlobalSortMode.custom.isCustom == true)
        #expect(GlobalSortMode.alphabetical(ascending: true).isCustom == false)
        #expect(GlobalSortMode.byAttribute(key: "status", ascending: true, type: .string).isCustom == false)
    }
}
