//
//  AppStatePersistenceTests.swift
//  Tiercade Tests
//
//  Created by AI Assistant on 9/30/25.
//

import XCTest
@testable import Tiercade
@testable import TiercadeCore

@MainActor
final class AppStatePersistenceTests: XCTestCase {
    
    var appState: AppState!
    let testKey = "TiercadeTests_AppState"
    
    override func setUp() async throws {
        appState = AppState()
        appState.storageKey = testKey
        UserDefaults.standard.removeObject(forKey: testKey)
    }
    
    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: testKey)
        appState = nil
    }
    
    // MARK: - Basic Save/Load Tests
    
    func testSaveAndLoad() {
        // Given: AppState with data
        appState.tiers["S"] = [
            Item(id: "item1", name: "Test Item 1", seasonString: "S1"),
            Item(id: "item2", name: "Test Item 2")
        ]
        appState.tiers["A"] = [
            Item(id: "item3", name: "Test Item 3")
        ]
        
        // When: Save and load
        XCTAssertTrue(appState.save())
        
        let newState = AppState()
        newState.storageKey = testKey
        XCTAssertTrue(newState.load())
        
        // Then: Data should match
        XCTAssertEqual(newState.tiers["S"]?.count, 2)
        XCTAssertEqual(newState.tiers["S"]?.first?.name, "Test Item 1")
        XCTAssertEqual(newState.tiers["A"]?.count, 1)
        XCTAssertEqual(newState.tiers["A"]?.first?.name, "Test Item 3")
    }
    
    func testSaveClearsUnsavedChangesFlag() {
        // Given
        appState.hasUnsavedChanges = true
        
        // When
        XCTAssertTrue(appState.save())
        
        // Then
        XCTAssertFalse(appState.hasUnsavedChanges)
    }
    
    func testAutoSaveOnlyWhenDirty() {
        // Given: Clean state
        appState.hasUnsavedChanges = false
        
        // When: AutoSave
        let result = appState.autoSave()
        
        // Then: Should succeed without actually saving
        XCTAssertTrue(result)
        XCTAssertNil(UserDefaults.standard.data(forKey: testKey))
    }
    
    func testAutoSaveWhenDirty() {
        // Given: Dirty state
        appState.tiers["S"] = [Item(id: "test")]
        appState.hasUnsavedChanges = true
        
        // When: AutoSave
        let result = appState.autoSave()
        
        // Then: Should actually save
        XCTAssertTrue(result)
        XCTAssertFalse(appState.hasUnsavedChanges)
        XCTAssertNotNil(UserDefaults.standard.data(forKey: testKey))
    }
    
    // MARK: - Empty State Tests
    
    func testLoadFromEmptyStorage() {
        // Given: No saved data
        UserDefaults.standard.removeObject(forKey: testKey)
        
        // When: Load
        let result = appState.load()
        
        // Then: Should fail gracefully
        XCTAssertFalse(result)
        XCTAssertTrue(appState.tiers.isEmpty || appState.tiers.values.allSatisfy { $0.isEmpty })
    }
    
    func testSaveEmptyTiers() {
        // Given: Empty tiers
        appState.tiers = [:]
        
        // When: Save
        XCTAssertTrue(appState.save())
        
        // Then: Should load successfully
        let newState = AppState()
        newState.storageKey = testKey
        XCTAssertTrue(newState.load())
        XCTAssertTrue(newState.tiers.isEmpty)
    }
    
    // MARK: - Item Attribute Tests
    
    func testSaveLoadWithAttributes() {
        // Given: Items with various attributes
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
        XCTAssertTrue(appState.save())
        
        let newState = AppState()
        newState.storageKey = testKey
        XCTAssertTrue(newState.load())
        
        // Then: All attributes preserved
        guard let loadedItem = newState.tiers["S"]?.first else {
            XCTFail("Item not loaded")
            return
        }
        
        XCTAssertEqual(loadedItem.id, "complex1")
        XCTAssertEqual(loadedItem.name, "Complex Item")
        XCTAssertEqual(loadedItem.imageUrl, "https://example.com/image.jpg")
        XCTAssertEqual(loadedItem.seasonString, "Season 5")
        XCTAssertEqual(loadedItem.seasonNumber, 5)
        XCTAssertEqual(loadedItem.videoUrl, "https://example.com/video.mp4")
        XCTAssertEqual(loadedItem.attributes?["director"], "Test Director")
        XCTAssertEqual(loadedItem.attributes?["rating"], "9.5")
    }
    
    // MARK: - File-Based Persistence Tests
    
    func testSaveToFile() {
        // Given
        let fileName = "test_tierlist"
        appState.tiers["S"] = [Item(id: "file_test")]
        
        // When
        XCTAssertTrue(appState.saveToFile(named: fileName))
        
        // Then: File should exist
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        
        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func testLoadFromFile() async throws {
        // Given: File with data
        let fileName = "test_load"
        appState.tiers["A"] = [Item(id: "file_load_test", name: "File Item")]
        XCTAssertTrue(appState.saveToFile(named: fileName))
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("\(fileName).json")
        
        // When: Load from file
        let newState = AppState()
        try await newState.loadFromFile(at: fileURL)
        
        // Then: Data should match
        XCTAssertEqual(newState.tiers["A"]?.first?.name, "File Item")
        
        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    // MARK: - Large Data Tests
    
    func testSaveLargeDataset() {
        // Given: Large dataset
        var items: [Item] = []
        for i in 1...1000 {
            items.append(Item(id: "item\(i)", name: "Test Item \(i)"))
        }
        appState.tiers["S"] = items
        
        // When: Save
        let startTime = Date()
        XCTAssertTrue(appState.save())
        let duration = Date().timeIntervalSince(startTime)
        
        // Then: Should complete quickly
        XCTAssertLessThan(duration, 1.0) // Less than 1 second
        
        // And: Should load correctly
        let newState = AppState()
        newState.storageKey = testKey
        XCTAssertTrue(newState.load())
        XCTAssertEqual(newState.tiers["S"]?.count, 1000)
    }
    
    // MARK: - Concurrent Access Tests
    
    func testConcurrentSaves() async throws {
        // Given: Multiple save operations
        let iterations = 10
        
        // When: Concurrent saves
        await withTaskGroup(of: Bool.self) { group in
            for i in 0..<iterations {
                group.addTask { @MainActor in
                    self.appState.tiers["S"] = [Item(id: "concurrent\(i)")]
                    return self.appState.save()
                }
            }
            
            // Then: All should succeed
            for await result in group {
                XCTAssertTrue(result)
            }
        }
    }
    
    // MARK: - Migration Tests
    
    func testNeedsMigration() {
        // Given: Modern format
        appState.tiers["S"] = [Item(id: "modern")]
        XCTAssertTrue(appState.saveToFile(named: "modern_test"))
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent("modern_test.json")
        
        // When: Check if migration needed
        let needsMigration = appState.needsMigration(at: fileURL)
        
        // Then: Should not need migration
        XCTAssertFalse(needsMigration)
        
        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
    }
    
    func testLegacyJSONStructureMigration() async throws {
        // Given: Legacy JSON format
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
        try legacyJSON.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // When: Migrate
        let migratedTiers = try await appState.migrateLegacySaveFile(at: fileURL)
        
        // Then: Should extract correctly
        XCTAssertEqual(migratedTiers["S"]?.first?.id, "legacy1")
        XCTAssertEqual(migratedTiers["S"]?.first?.name, "Legacy Item")
        XCTAssertEqual(migratedTiers["A"]?.first?.id, "legacy2")
        
        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
        let backupURL = fileURL.deletingPathExtension().appendingPathExtension("legacy.backup.json")
        try? FileManager.default.removeItem(at: backupURL)
    }
    
    func testFlatItemArrayMigration() async throws {
        // Given: Legacy flat array format
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
        try legacyJSON.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // When: Migrate
        let migratedTiers = try await appState.migrateLegacySaveFile(at: fileURL)
        
        // Then: Should organize by tier
        XCTAssertEqual(migratedTiers["S"]?.count, 1)
        XCTAssertEqual(migratedTiers["A"]?.count, 1)
        XCTAssertEqual(migratedTiers["unranked"]?.count, 1)
        
        // Cleanup
        try? FileManager.default.removeItem(at: fileURL)
        let backupURL = fileURL.deletingPathExtension().appendingPathExtension("legacy.backup.json")
        try? FileManager.default.removeItem(at: backupURL)
    }
}
