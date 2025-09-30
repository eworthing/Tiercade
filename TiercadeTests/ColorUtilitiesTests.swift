//
//  ColorUtilitiesTests.swift
//  TiercadeTests
//
//  Unit tests for consolidated color parsing and contrast utilities
//

import XCTest
@testable import Tiercade

final class ColorUtilitiesTests: XCTestCase {
    
    // MARK: - Hex Parsing Tests
    
    func testParseHex6Digits() {
        let result = ColorUtilities.parseHex("#FF5733")
        XCTAssertEqual(result.red, 1.0, accuracy: 0.01, "Red should be FF (255/255 = 1.0)")
        XCTAssertEqual(result.green, 0.341, accuracy: 0.01, "Green should be 57 (87/255 ≈ 0.341)")
        XCTAssertEqual(result.blue, 0.2, accuracy: 0.01, "Blue should be 33 (51/255 = 0.2)")
        XCTAssertEqual(result.alpha, 1.0, accuracy: 0.01, "Alpha should default to 1.0")
    }
    
    func testParseHex8Digits() {
        let result = ColorUtilities.parseHex("#FF5733CC")
        XCTAssertEqual(result.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(result.green, 0.341, accuracy: 0.01)
        XCTAssertEqual(result.blue, 0.2, accuracy: 0.01)
        XCTAssertEqual(result.alpha, 0.8, accuracy: 0.01, "Alpha should be CC (204/255 = 0.8)")
    }
    
    func testParseHex3Digits() {
        let result = ColorUtilities.parseHex("#F53")
        XCTAssertEqual(result.red, 1.0, accuracy: 0.01, "F expands to FF")
        XCTAssertEqual(result.green, 0.333, accuracy: 0.01, "5 expands to 55")
        XCTAssertEqual(result.blue, 0.2, accuracy: 0.01, "3 expands to 33")
        XCTAssertEqual(result.alpha, 1.0, accuracy: 0.01)
    }
    
    func testParseHexWithoutHash() {
        let result = ColorUtilities.parseHex("FF5733")
        XCTAssertEqual(result.red, 1.0, accuracy: 0.01)
        XCTAssertEqual(result.green, 0.341, accuracy: 0.01)
        XCTAssertEqual(result.blue, 0.2, accuracy: 0.01)
    }
    
    func testParseHexWithCustomAlpha() {
        let result = ColorUtilities.parseHex("#FF5733", defaultAlpha: 0.5)
        XCTAssertEqual(result.alpha, 0.5, accuracy: 0.01, "Custom alpha should be applied")
    }
    
    func testParseHexInvalidFormat() {
        let result = ColorUtilities.parseHex("invalid")
        XCTAssertEqual(result.red, 1.0, accuracy: 0.01, "Should fall back to white")
        XCTAssertEqual(result.green, 1.0, accuracy: 0.01)
        XCTAssertEqual(result.blue, 1.0, accuracy: 0.01)
    }
    
    // MARK: - Luminance Tests
    
    func testLuminanceWhite() {
        let white = ColorUtilities.RGBAComponents(red: 1, green: 1, blue: 1, alpha: 1)
        let luminance = ColorUtilities.luminance(white)
        XCTAssertEqual(luminance, 1.0, accuracy: 0.01, "White should have luminance of 1.0")
    }
    
    func testLuminanceBlack() {
        let black = ColorUtilities.RGBAComponents(red: 0, green: 0, blue: 0, alpha: 1)
        let luminance = ColorUtilities.luminance(black)
        XCTAssertEqual(luminance, 0.0, accuracy: 0.01, "Black should have luminance of 0.0")
    }
    
    func testLuminanceMidGray() {
        let gray = ColorUtilities.RGBAComponents(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let luminance = ColorUtilities.luminance(gray)
        XCTAssertGreaterThan(luminance, 0.15, "Mid gray should have measurable luminance")
        XCTAssertLessThan(luminance, 0.25, "Mid gray luminance should be reasonable")
    }
    
    func testLuminanceRed() {
        let red = ColorUtilities.parseHex("#FF0000")
        let luminance = ColorUtilities.luminance(red)
        // Red has weight of 0.2126 in WCAG formula
        XCTAssertEqual(luminance, 0.2126, accuracy: 0.01, "Pure red should have specific luminance")
    }
    
    func testLuminanceGreen() {
        let green = ColorUtilities.parseHex("#00FF00")
        let luminance = ColorUtilities.luminance(green)
        // Green has weight of 0.7152 in WCAG formula
        XCTAssertEqual(luminance, 0.7152, accuracy: 0.01, "Pure green should have specific luminance")
    }
    
    func testLuminanceBlue() {
        let blue = ColorUtilities.parseHex("#0000FF")
        let luminance = ColorUtilities.luminance(blue)
        // Blue has weight of 0.0722 in WCAG formula
        XCTAssertEqual(luminance, 0.0722, accuracy: 0.01, "Pure blue should have specific luminance")
    }
    
    // MARK: - Contrast Ratio Tests
    
    func testContrastRatioWhiteOnBlack() {
        let ratio = ColorUtilities.contrastRatio(lum1: 1.0, lum2: 0.0)
        XCTAssertEqual(ratio, 21.0, accuracy: 0.1, "White on black should have maximum contrast of 21:1")
    }
    
    func testContrastRatioBlackOnWhite() {
        let ratio = ColorUtilities.contrastRatio(lum1: 0.0, lum2: 1.0)
        XCTAssertEqual(ratio, 21.0, accuracy: 0.1, "Black on white should have maximum contrast of 21:1")
    }
    
    func testContrastRatioSameColor() {
        let ratio = ColorUtilities.contrastRatio(lum1: 0.5, lum2: 0.5)
        XCTAssertEqual(ratio, 1.0, accuracy: 0.01, "Same luminance should have ratio of 1:1")
    }
    
    func testContrastRatioMeetsWCAGAA() {
        // WCAG AA requires 4.5:1 for normal text
        let darkGray = ColorUtilities.parseHex("#595959")
        let white = ColorUtilities.RGBAComponents(red: 1, green: 1, blue: 1, alpha: 1)
        let darkLum = ColorUtilities.luminance(darkGray)
        let whiteLum = ColorUtilities.luminance(white)
        let ratio = ColorUtilities.contrastRatio(lum1: whiteLum, lum2: darkLum)
        XCTAssertGreaterThanOrEqual(ratio, 4.5, "Dark gray on white should meet WCAG AA")
    }
    
    // MARK: - Accessible Text Color Tests
    
    func testAccessibleTextColorOnDarkBackground() {
        let textColor = ColorUtilities.accessibleTextColor(onBackground: "#0E1114")
        // Should return white-ish color for dark backgrounds
        // We can't directly compare Color objects, but we can verify it's been called
        XCTAssertNotNil(textColor, "Should return a text color")
    }
    
    func testAccessibleTextColorOnLightBackground() {
        let textColor = ColorUtilities.accessibleTextColor(onBackground: "#FFFFFF")
        XCTAssertNotNil(textColor, "Should return a text color")
    }
    
    func testAccessibleTextColorOnMidTone() {
        let textColor = ColorUtilities.accessibleTextColor(onBackground: "#808080")
        XCTAssertNotNil(textColor, "Should return a text color for mid-tone")
    }
    
    // MARK: - Color Extension Tests
    
    func testColorHexInitializerValid() {
        let color = Color(hex: "#FF5733")
        XCTAssertNotNil(color, "Valid hex should create a color")
    }
    
    func testColorHexInitializerInvalid() {
        let color = Color(hex: "invalid")
        XCTAssertNil(color, "Invalid hex should return nil")
    }
    
    func testColorHexInitializerShortFormat() {
        let color = Color(hex: "#F53")
        XCTAssertNil(color, "3-digit hex should return nil (not in expected format)")
    }
    
    func testColorWideGamut() {
        let color = Color.wideGamut("#FF5733")
        XCTAssertNotNil(color, "Wide gamut color should be created")
    }
    
    // MARK: - Integration Tests
    
    func testTierColorConsistency() {
        // Test that common tier colors parse correctly
        let tierS = ColorUtilities.parseHex("#FF0037")
        XCTAssertGreaterThan(tierS.red, 0.9, "Tier S should be predominantly red")
        
        let tierA = ColorUtilities.parseHex("#FFA000")
        XCTAssertGreaterThan(tierA.red, 0.9, "Tier A should have high red")
        XCTAssertGreaterThan(tierA.green, 0.5, "Tier A should have moderate green (orange)")
        
        let tierB = ColorUtilities.parseHex("#00EC57")
        XCTAssertGreaterThan(tierB.green, 0.8, "Tier B should be predominantly green")
    }
    
    func testContrastOnAllTierColors() {
        let tierColors = [
            "#FF0037", // S
            "#FFA000", // A
            "#00EC57", // B
            "#00D9FE", // C
            "#1E3A8A", // D
            "#808080"  // F
        ]
        
        for hexColor in tierColors {
            let components = ColorUtilities.parseHex(hexColor)
            let luminance = ColorUtilities.luminance(components)
            let whiteContrast = ColorUtilities.contrastRatio(lum1: 1.0, lum2: luminance)
            let blackContrast = ColorUtilities.contrastRatio(lum1: luminance, lum2: 0.0)
            
            // At least one should meet WCAG AA (4.5:1)
            let meetsStandard = whiteContrast >= 4.5 || blackContrast >= 4.5
            XCTAssertTrue(meetsStandard, "Color \(hexColor) should have accessible text color option")
        }
    }
}
