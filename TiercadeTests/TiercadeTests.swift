//
//  TiercadeTests.swift
//  TiercadeTests
//
//  Created by PL on 9/14/25.
//

import XCTest
@testable import Tiercade

final class TiercadeTests: XCTestCase {

    @MainActor
    func testRandomize() throws {
        let appState = AppState()
        
        // Set up initial state with contestants in different tiers
        appState.tiers = [
            "S": [TLContestant(id: "1", name: "Player 1", season: "1")],
            "A": [TLContestant(id: "2", name: "Player 2", season: "2")],
            "B": [],
            "C": [TLContestant(id: "3", name: "Player 3", season: "3")],
            "D": [],
            "F": [],
            "unranked": [
                TLContestant(id: "4", name: "Player 4", season: "4"),
                TLContestant(id: "5", name: "Player 5", season: "5")
            ]
        ]
        
        // Count contestants before randomize
        let sTierCount = appState.tiers["S"]?.count ?? 0
        let aTierCount = appState.tiers["A"]?.count ?? 0
        let bTierCount = appState.tiers["B"]?.count ?? 0
        let cTierCount = appState.tiers["C"]?.count ?? 0
        let dTierCount = appState.tiers["D"]?.count ?? 0
        let fTierCount = appState.tiers["F"]?.count ?? 0
        let unrankedCount = appState.tiers["unranked"]?.count ?? 0
        let originalCount = sTierCount + aTierCount + bTierCount + cTierCount + dTierCount + fTierCount + unrankedCount
        
        // Call randomize
        appState.randomize()
        
        // Count contestants after randomize
        let newSTierCount = appState.tiers["S"]?.count ?? 0
        let newATierCount = appState.tiers["A"]?.count ?? 0
        let newBTierCount = appState.tiers["B"]?.count ?? 0
        let newCTierCount = appState.tiers["C"]?.count ?? 0
        let newDTierCount = appState.tiers["D"]?.count ?? 0
        let newFTierCount = appState.tiers["F"]?.count ?? 0
        let newUnrankedCount = appState.tiers["unranked"]?.count ?? 0
        let newCount = newSTierCount + newATierCount + newBTierCount + newCTierCount + newDTierCount + newFTierCount + newUnrankedCount
        
        XCTAssertEqual(originalCount, newCount, "Randomize should preserve total contestant count")
        
        // Check that unranked should be empty after randomize (contestants distributed to tiers)
        XCTAssertEqual(newUnrankedCount, 0, "Unranked should be empty after randomize")
        
        // Check that contestants are distributed across tiers
        var tiersWithContestants = 0
        for tier in appState.tierOrder {
            let tierCount = appState.tiers[tier]?.count ?? 0
            if tierCount > 0 {
                tiersWithContestants += 1
            }
        }
        
        XCTAssertGreaterThan(tiersWithContestants, 0, "At least one tier should have contestants after randomize")
    }
    
    @MainActor
    func testClearTier() throws {
        let appState = AppState()
        
        // Set up initial state
        appState.tiers = [
            "S": [
                TLContestant(id: "1", name: "Player 1", season: "1"),
                TLContestant(id: "2", name: "Player 2", season: "2")
            ],
            "A": [TLContestant(id: "3", name: "Player 3", season: "3")],
            "B": [], "C": [], "D": [], "F": [],
            "unranked": []
        ]
        
        let originalSCount = appState.tiers["S"]?.count ?? 0
        let originalUnrankedCount = appState.tiers["unranked"]?.count ?? 0
        
        // Clear S tier
        appState.clearTier("S")
        
        // Check that S tier is now empty
        let sCount = appState.tiers["S"]?.count ?? 0
        XCTAssertEqual(sCount, 0, "S tier should be empty after clearing")
        
        // Check that contestants moved to unranked
        let unrankedCount = appState.tiers["unranked"]?.count ?? 0
        XCTAssertEqual(unrankedCount, originalUnrankedCount + originalSCount, "Unranked should contain the moved contestants")
        
        // Check that A tier was not affected
        let aCount = appState.tiers["A"]?.count ?? 0
        XCTAssertEqual(aCount, 1, "A tier should remain unchanged")
    }

    func testExample() throws {
        // Write your unit test here.
        XCTAssertTrue(true)
    }

}
