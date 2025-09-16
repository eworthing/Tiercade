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
        let originalCount = sTierCount + aTierCount + bTierCount + cTierCount + dTierCount + fTierCount + unrankedCount
        
        // Call randomize
        appState.randomize()
        
    // Count items after randomize
    let newSTierCount = appState.tierCount("S")
    let newATierCount = appState.tierCount("A")
    let newBTierCount = appState.tierCount("B")
    let newCTierCount = appState.tierCount("C")
    let newDTierCount = appState.tierCount("D")
    let newFTierCount = appState.tierCount("F")
    let newUnrankedCount = appState.unrankedCount()
        let newCount = newSTierCount + newATierCount + newBTierCount + newCTierCount + newDTierCount + newFTierCount + newUnrankedCount
        
    XCTAssertEqual(originalCount, newCount, "Randomize should preserve total item count")
        
    // Check that unranked should be empty after randomize (items distributed to tiers)
        XCTAssertEqual(newUnrankedCount, 0, "Unranked should be empty after randomize")
        
    // Check that items are distributed across tiers
        var tiersWithItems = 0
        for tier in appState.tierOrder {
            let tierCount = appState.tierCount(tier)
            if tierCount > 0 {
                tiersWithItems += 1
            }
        }
    
    XCTAssertGreaterThan(tiersWithItems, 0, "At least one tier should have items after randomize")
    }
    
    @MainActor
    func testClearTier() throws {
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
        XCTAssertEqual(sCount, 0, "S tier should be empty after clearing")
        
    // Check that items moved to unranked
    let unrankedCount = appState.unrankedCount()
    XCTAssertEqual(unrankedCount, originalUnrankedCount + originalSCount, "Unranked should contain the moved items")
        
        // Check that A tier was not affected
    let aCount = appState.tierCount("A")
    XCTAssertEqual(aCount, 1, "A tier should remain unchanged")
    }

    func testExample() throws {
        // Write your unit test here.
        XCTAssertTrue(true)
    }

}
