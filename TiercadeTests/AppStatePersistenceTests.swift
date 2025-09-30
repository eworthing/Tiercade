//
//  AppStatePersistenceTests.swift
//  Tiercade Tests
//
//  Created by AI Assistant on 9/30/25.
//

import Testing
@testable import Tiercade
@testable import TiercadeCore

@Suite("AppState Persistence Tests")
@MainActor
struct AppStatePersistenceTests {

    let testKey = "TiercadeTests_AppState"

    init() {
        // Setup equivalent
        UserDefaults.standard.removeObject(forKey: testKey)
    }

    // MARK: - Basic Save/Load Tests

    @Test("Save and load preserves tier data")
    func saveAndLoad() throws {
        // Given: AppState with data
        let appState = AppState()
        appState.storageKey = testKey
        defer { UserDefaults.standard.removeObject(forKey: testKey) }

        appState.tiers["S"] = [
            Item(id: "item1", name: "Test Item 1", seasonString: "S1"),
            Item(id: "item2", name: "Test Item 2")
        ]
        appState.tiers["A"] = [
            Item(id: "item3", name: "Test Item 3")
        ]

        // When: Save and load
        try appState.save()

        let newState = AppState()
        newState.storageKey = testKey
        try newState.load()

        // Then: Data should match
        #expect(newState.tiers["S"]?.count == 2)
        #expect(newState.tiers["S"]?.first?.name == "Test Item 1")
        #expect(newState.tiers["A"]?.count == 1)
        #expect(newState.tiers["A"]?.first?.name == "Test Item 3")
    }

    @Test("Save clears unsaved changes flag")
    func saveClearsUnsavedChangesFlag() throws {
        // Given
        let appState = AppState()
        appState.storageKey = testKey
        defer { UserDefaults.standard.removeObject(forKey: testKey) }
        appState.hasUnsavedChanges = true

        // When
        try appState.save()

        // Then
        #expect(!appState.hasUnsavedChanges)
    }

    @Test("AutoSave skips when state is clean")
    func autoSaveOnlyWhenDirty() throws {
        // Given: Clean state
        let appState = AppState()
        appState.storageKey = testKey
        defer { UserDefaults.standard.removeObject(forKey: testKey) }
        appState.hasUnsavedChanges = false

        // When: AutoSave
        try appState.autoSave()

        // Then: Should succeed without actually saving
        #expect(UserDefaults.standard.data(forKey: testKey) == nil)
    }

    @Test("AutoSave persists when state is dirty")
    func autoSaveWhenDirty() throws {
        // Given: Dirty state
        let appState = AppState()
        appState.storageKey = testKey
        defer { UserDefaults.standard.removeObject(forKey: testKey) }
        appState.tiers["S"] = [Item(id: "test")]
        appState.hasUnsavedChanges = true

        // When: AutoSave
        try appState.autoSave()

        // Then: Should actually save
        #expect(!appState.hasUnsavedChanges)
        #expect(UserDefaults.standard.data(forKey: testKey) != nil)
    }

    // MARK: - Empty State Tests

    @Test("Load from empty storage fails gracefully")
    func loadFromEmptyStorage() throws {
        // Given: No saved data
        let appState = AppState()
        appState.storageKey = testKey
        defer { UserDefaults.standard.removeObject(forKey: testKey) }
        UserDefaults.standard.removeObject(forKey: testKey)

        // When: Load
        #expect(throws: PersistenceError.self) {
            try appState.load()
        }
    }

    @Test("Save and load empty tiers")
    func saveEmptyTiers() throws {
        // Given: Empty tiers
        let appState = AppState()
        appState.storageKey = testKey
        defer { UserDefaults.standard.removeObject(forKey: testKey) }
        appState.tiers = [:]

        // When: Save
        try appState.save()

        // Then: Should load successfully
        let newState = AppState()
        newState.storageKey = testKey
        try newState.load()
        #expect(newState.tiers.isEmpty)
    }

    // MARK: - Item Attribute Tests

    @Test("Save and load preserves all item attributes")
    func saveLoadWithAttributes() throws {
        // Given: Items with various attributes
        let appState = AppState()
        appState.storageKey = testKey
        defer { UserDefaults.standard.removeObject(forKey: testKey) }

        let item = Item(
            id: "complex1",
            name: "Complex Item",
            imageUrl: "https://example.com/image.jpg",
            seasonString: "Season 5",
            seasonNumber: 5,
            videoUrl: "https://example.com/video.mp4",
            attributes: [
                "director": "Test Director",
                "rating": "9.5"
            ]
        )
        appState.tiers["S"] = [item]

        // When: Save and load
        try appState.save()

        let newState = AppState()
        newState.storageKey = testKey
        try newState.load()

        // Then: All attributes preserved
        guard let loadedItem = newState.tiers["S"]?.first else {
            Issue.record("Item not loaded")
            return
        }

        #expect(loadedItem.id == "complex1")
        #expect(loadedItem.name == "Complex Item")
        #expect(loadedItem.imageUrl == "https://example.com/image.jpg")
        #expect(loadedItem.seasonString == "Season 5")
        #expect(loadedItem.seasonNumber == 5)
        #expect(loadedItem.videoUrl == "https://example.com/video.mp4")
        #expect(loadedItem.attributes?["director"] == "Test Director")
        #expect(loadedItem.attributes?["rating"] == "9.5")
    }

    // MARK: - File-Based Persistence Tests

    @Test("Save to file creates file successfully")
    func saveToFile() throws {
        // Given
        let appState = AppState()
        let fileName = "test_tierlist"
        appState.tiers["S"] = [Item(id: "file_test")]

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        // When
        try appState.saveToFile(named: fileName)

        // Then: File should exist
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("Load from file restores data")
    func loadFromFile() async throws {
        // Given: File with data
        let appState = AppState()
        let fileName = "test_load"
        appState.tiers["A"] = [Item(id: "file_load_test", name: "File Item")]

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        try appState.saveToFile(named: fileName)

        // When: Load from file
        let newState = AppState()
        try await newState.loadFromFile(at: fileURL)

        // Then: Data should match
        #expect(newState.tiers["A"]?.first?.name == "File Item")
    }

    // MARK: - Large Data Tests

    @Test("Save large dataset completes quickly")
    func saveLargeDataset() throws {
        // Given: Large dataset
        let appState = AppState()
        appState.storageKey = testKey
        defer { UserDefaults.standard.removeObject(forKey: testKey) }

        var items: [Item] = []
        for i in 1...1000 {
            items.append(Item(id: "item\(i)", name: "Test Item \(i)"))
        }
        appState.tiers["S"] = items

        // When: Save
        let startTime = Date()
        try appState.save()
        let duration = Date().timeIntervalSince(startTime)

        // Then: Should complete quickly
        #expect(duration < 1.0, "Save should complete in less than 1 second")

        // And: Should load correctly
        let newState = AppState()
        newState.storageKey = testKey
        try newState.load()
        #expect(newState.tiers["S"]?.count == 1000)
    }

    // MARK: - Concurrent Access Tests

    @Test("Concurrent saves all succeed")
    func concurrentSaves() async throws {
        // Given: Multiple save operations
        let appState = AppState()
        appState.storageKey = testKey
        defer { UserDefaults.standard.removeObject(forKey: testKey) }
        let iterations = 10

        // When: Concurrent saves
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask { @MainActor in
                    appState.tiers["S"] = [Item(id: "concurrent\(i)")]
                    try? appState.save()
                }
            }
        }

        // Then: Should have saved successfully (last one wins)
        #expect(UserDefaults.standard.data(forKey: testKey) != nil)
    }

    // MARK: - Migration Tests

    @Test("Modern format does not need migration")
    func needsMigration() throws {
        // Given: Modern format
        let appState = AppState()
        appState.tiers["S"] = [Item(id: "modern")]
        try appState.saveToFile(named: "modern_test")

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("modern_test.json")
        defer { try? FileManager.default.removeItem(at: fileURL) }

        // When: Check if migration needed
        let needsMigration = appState.needsMigration(at: fileURL)

        // Then: Should not need migration
        #expect(!needsMigration)
    }

    @Test("Legacy JSON structure migrates correctly")
    func legacyJSONStructureMigration() async throws {
        // Given: Legacy JSON format
        let appState = AppState()
        let legacyJSON = """
        {
            "tiers": {
                "S": [{"id": "legacy1", "name": "Legacy Item"}],
                "A": [{"id": "legacy2", "name": "Another Legacy"}]
            }
        }
        """

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("legacy_test.json")
        let backupURL = fileURL.deletingPathExtension().appendingPathExtension("legacy.backup.json")
        defer {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: backupURL)
        }

        try legacyJSON.write(to: fileURL, atomically: true, encoding: .utf8)

        // When: Migrate
        let migratedTiers = try await appState.migrateLegacySaveFile(at: fileURL)

        // Then: Should extract correctly
        #expect(migratedTiers["S"]?.first?.id == "legacy1")
        #expect(migratedTiers["S"]?.first?.name == "Legacy Item")
        #expect(migratedTiers["A"]?.first?.id == "legacy2")
    }

    @Test("Flat item array migrates to tiered structure")
    func flatItemArrayMigration() async throws {
        // Given: Legacy flat array format
        let appState = AppState()
        let legacyJSON = """
        {
            "items": [
                {"id": "flat1", "tier": "S", "name": "Flat Item 1"},
                {"id": "flat2", "tier": "A", "name": "Flat Item 2"},
                {"id": "flat3", "name": "Unranked Item"}
            ]
        }
        """

        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("flat_test.json")
        let backupURL = fileURL.deletingPathExtension().appendingPathExtension("legacy.backup.json")
        defer {
            try? FileManager.default.removeItem(at: fileURL)
            try? FileManager.default.removeItem(at: backupURL)
        }

        try legacyJSON.write(to: fileURL, atomically: true, encoding: .utf8)

        // When: Migrate
        let migratedTiers = try await appState.migrateLegacySaveFile(at: fileURL)

        // Then: Should organize by tier
        #expect(migratedTiers["S"]?.count == 1)
        #expect(migratedTiers["A"]?.count == 1)
        #expect(migratedTiers["unranked"]?.count == 1)
    }
}
