//
//  TiercadeTests.swift
//  TiercadeTests
//
//  Created by PL on 9/14/25.
//

import Testing
@testable import Tiercade
import TiercadeCore

@Suite("Tiercade Core Tests")
@MainActor
struct TiercadeTests {

    @Test("Randomize distributes items across tiers and clears unranked")
    func randomize() async throws {
        let appState = AppState()

        // Set up initial state with items in different tiers
        appState.tiers = [
            "S": [Item(id: "1", attributes: ["name": "Player 1", "season": "1"])],
            "A": [Item(id: "2", attributes: ["name": "Player 2", "season": "2"])],
            "B": [],
            "C": [Item(id: "3", attributes: ["name": "Player 3", "season": "3"])],
            "D": [],
            "F": [],
            "unranked": [
                Item(id: "4", attributes: ["name": "Player 4", "season": "4"]),
                Item(id: "5", attributes: ["name": "Player 5", "season": "5"])
            ]
        ]

        // Count items before randomize
        let sTierCount = appState.tierCount("S")
        let aTierCount = appState.tierCount("A")
        let bTierCount = appState.tierCount("B")
        let cTierCount = appState.tierCount("C")
        let dTierCount = appState.tierCount("D")
        let fTierCount = appState.tierCount("F")
        let unrankedCount = appState.unrankedCount()
        let originalCount = [
            sTierCount,
            aTierCount,
            bTierCount,
            cTierCount,
            dTierCount,
            fTierCount,
            unrankedCount
        ].reduce(0, +)

        // Call randomize
        appState.randomize()

        // Count items after randomize
        let countsAfter = [
            appState.tierCount("S"),
            appState.tierCount("A"),
            appState.tierCount("B"),
            appState.tierCount("C"),
            appState.tierCount("D"),
            appState.tierCount("F"),
            appState.unrankedCount()
        ]
        let newCount = countsAfter.reduce(0, +)

        #expect(originalCount == newCount, "Randomize should preserve total item count")

        // Check that unranked should be empty after randomize (items distributed to tiers)
        let newUnrankedCount = countsAfter.last ?? 0
        #expect(newUnrankedCount == 0, "Unranked should be empty after randomize")

        // Check that items are distributed across tiers
        let tiersWithItems = appState.tierOrder
            .map { appState.tierCount($0) }
            .filter { $0 > 0 }
            .count

        #expect(tiersWithItems > 0, "At least one tier should have items after randomize")
    }

    @Test("Clear tier moves items to unranked")
    func clearTier() async throws {
        let appState = AppState()

        // Set up initial state
        appState.tiers = [
            "S": [
                Item(id: "1", attributes: ["name": "Player 1", "season": "1"]),
                Item(id: "2", attributes: ["name": "Player 2", "season": "2"])
            ],
            "A": [Item(id: "3", attributes: ["name": "Player 3", "season": "3"])],
            "B": [], "C": [], "D": [], "F": [],
            "unranked": []
        ]

        let originalSCount = appState.tierCount("S")
        let originalUnrankedCount = appState.unrankedCount()

        // Clear S tier
        appState.clearTier("S")

        // Check that S tier is now empty
        let sCount = appState.tierCount("S")
        #expect(sCount == 0, "S tier should be empty after clearing")

        // Check that items moved to unranked
        let unrankedCount = appState.unrankedCount()
        #expect(unrankedCount == originalUnrankedCount + originalSCount, "Unranked should contain the moved items")

        // Check that A tier was not affected
        let aCount = appState.tierCount("A")
        #expect(aCount == 1, "A tier should remain unchanged")
    }

    @Test("Example test always passes")
    func example() async throws {
        // Write your unit test here.
        #expect(true)
    }

    @Test("Completing theme creation registers a custom theme")
    func createCustomTheme() async throws {
        let appState = AppState()
        appState.customThemes = []
        appState.customThemeIDs = []
        appState.themeDraft = nil

        let baseTheme = appState.selectedTheme

        appState.beginThemeCreation(baseTheme: baseTheme)
        appState.updateThemeDraftName("Test Custom Theme")
        appState.updateThemeDraftDescription("Verifies theme creation workflow")

        if let tierID = appState.themeDraft?.tiers.first?.id {
            appState.selectThemeDraftTier(tierID)
            appState.assignColorToActiveTier("#FFAA00")
        }

        appState.completeThemeCreation()

        #expect(appState.customThemes.contains { $0.displayName == "Test Custom Theme" })
        #expect(appState.selectedTheme.displayName == "Test Custom Theme")
        #expect(appState.isCustomTheme(appState.selectedTheme))
    }

    @Test("Bundled themes expose unique ranked tiers")
    func bundledThemesExposeUniqueRankedTiers() async throws {
        struct TierKey: Hashable {
            let index: Int
            let name: String
        }

        for theme in TierThemeCatalog.allThemes {
            let rankedKeys = theme.rankedTiers.map { tier in
                TierKey(
                    index: tier.index,
                    name: tier.name
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .lowercased()
                )
            }
            #expect(
                Set(rankedKeys).count == rankedKeys.count,
                "Theme \(theme.slug) contains duplicate ranked tiers"
            )

            let unrankedCount = theme.tiers.filter(\.isUnranked).count
            #expect(unrankedCount <= 1, "Theme \(theme.slug) defines multiple unranked tiers")
        }
    }

    @Test("JSON import appends new tiers when order is omitted")
    func jsonImportAppendsNewTiers() async throws {
        let appState = AppState()

        let json = """
        {
          "tiers": {
            "S": [{"id": "s-tier"}],
            "Legends": [{"id": "legend-1", "name": "Legend"}]
          }
        }
        """

        try await appState.importFromJSON(json)

        #expect(appState.tierOrder.contains("Legends"), "Imported tiers should be added to the order")
        #expect(appState.tiers["Legends"]?.count == 1)
    }

    @Test("JSON import respects explicit tier order while ensuring visibility")
    func jsonImportRespectsExplicitOrder() async throws {
        let appState = AppState()

        let json = """
        {
          "tierOrder": ["Legends", "S"],
          "tiers": {
            "S": [{"id": "s-tier"}],
            "Legends": [{"id": "legend-1"}],
            "Masters": [{"id": "master-1"}]
          }
        }
        """

        try await appState.importFromJSON(json)

        #expect(Array(appState.tierOrder.prefix(2)) == ["Legends", "S"], "Explicit order should be honored")
        #expect(appState.tierOrder.contains("Masters"), "Tiers missing from the explicit order should still appear")
    }

}
