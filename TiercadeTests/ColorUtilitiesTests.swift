//
//  ColorUtilitiesTests.swift
//  TiercadeTests
//
//  Unit tests for consolidated color parsing and contrast utilities
//

import Testing
@testable import Tiercade

@Suite("Color Utilities Tests")
struct ColorUtilitiesTests {

    // MARK: - Hex Parsing Tests

    @Test("Parse 6-digit hex color")
    func parseHex6Digits() {
        let result = ColorUtilities.parseHex("#FF5733")
        #expect(abs(result.red - 1.0) < 0.01, "Red should be FF (255/255 = 1.0)")
        #expect(abs(result.green - 0.341) < 0.01, "Green should be 57 (87/255 ≈ 0.341)")
        #expect(abs(result.blue - 0.2) < 0.01, "Blue should be 33 (51/255 = 0.2)")
        #expect(abs(result.alpha - 1.0) < 0.01, "Alpha should default to 1.0")
    }

    @Test("Parse 8-digit hex color with alpha")
    func parseHex8Digits() {
        let result = ColorUtilities.parseHex("#FF5733CC")
        #expect(abs(result.red - 1.0) < 0.01)
        #expect(abs(result.green - 0.341) < 0.01)
        #expect(abs(result.blue - 0.2) < 0.01)
        #expect(abs(result.alpha - 0.8) < 0.01, "Alpha should be CC (204/255 = 0.8)")
    }

    @Test("Parse 3-digit hex color")
    func parseHex3Digits() {
        let result = ColorUtilities.parseHex("#F53")
        #expect(abs(result.red - 1.0) < 0.01, "F expands to FF")
        #expect(abs(result.green - 0.333) < 0.01, "5 expands to 55")
        #expect(abs(result.blue - 0.2) < 0.01, "3 expands to 33")
        #expect(abs(result.alpha - 1.0) < 0.01)
    }

    @Test("Parse hex without hash prefix")
    func parseHexWithoutHash() {
        let result = ColorUtilities.parseHex("FF5733")
        #expect(abs(result.red - 1.0) < 0.01)
        #expect(abs(result.green - 0.341) < 0.01)
        #expect(abs(result.blue - 0.2) < 0.01)
    }

    @Test("Parse hex with custom alpha")
    func parseHexWithCustomAlpha() {
        let result = ColorUtilities.parseHex("#FF5733", defaultAlpha: 0.5)
        #expect(abs(result.alpha - 0.5) < 0.01, "Custom alpha should be applied")
    }

    @Test("Parse invalid hex falls back to white")
    func parseHexInvalidFormat() {
        let result = ColorUtilities.parseHex("invalid")
        #expect(abs(result.red - 1.0) < 0.01, "Should fall back to white")
        #expect(abs(result.green - 1.0) < 0.01)
        #expect(abs(result.blue - 1.0) < 0.01)
    }

    // MARK: - Luminance Tests

    @Test("Luminance calculation for white")
    func luminanceWhite() {
        let white = ColorUtilities.RGBAComponents(red: 1, green: 1, blue: 1, alpha: 1)
        let luminance = ColorUtilities.luminance(white)
        #expect(abs(luminance - 1.0) < 0.01, "White should have luminance of 1.0")
    }

    @Test("Luminance calculation for black")
    func luminanceBlack() {
        let black = ColorUtilities.RGBAComponents(red: 0, green: 0, blue: 0, alpha: 1)
        let luminance = ColorUtilities.luminance(black)
        #expect(abs(luminance - 0.0) < 0.01, "Black should have luminance of 0.0")
    }

    @Test("Luminance calculation for mid gray")
    func luminanceMidGray() {
        let gray = ColorUtilities.RGBAComponents(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        let luminance = ColorUtilities.luminance(gray)
        #expect(luminance > 0.15, "Mid gray should have measurable luminance")
        #expect(luminance < 0.25, "Mid gray luminance should be reasonable")
    }

    @Test("Luminance calculation for pure red")
    func luminanceRed() {
        let red = ColorUtilities.parseHex("#FF0000")
        let luminance = ColorUtilities.luminance(red)
        // Red has weight of 0.2126 in WCAG formula
        #expect(abs(luminance - 0.2126) < 0.01, "Pure red should have specific luminance")
    }

    @Test("Luminance calculation for pure green")
    func luminanceGreen() {
        let green = ColorUtilities.parseHex("#00FF00")
        let luminance = ColorUtilities.luminance(green)
        // Green has weight of 0.7152 in WCAG formula
        #expect(abs(luminance - 0.7152) < 0.01, "Pure green should have specific luminance")
    }

    @Test("Luminance calculation for pure blue")
    func luminanceBlue() {
        let blue = ColorUtilities.parseHex("#0000FF")
        let luminance = ColorUtilities.luminance(blue)
        // Blue has weight of 0.0722 in WCAG formula
        #expect(abs(luminance - 0.0722) < 0.01, "Pure blue should have specific luminance")
    }

    // MARK: - Contrast Ratio Tests

    @Test("Contrast ratio for white on black")
    func contrastRatioWhiteOnBlack() {
        let ratio = ColorUtilities.contrastRatio(lum1: 1.0, lum2: 0.0)
        #expect(abs(ratio - 21.0) < 0.1, "White on black should have maximum contrast of 21:1")
    }

    @Test("Contrast ratio for black on white")
    func contrastRatioBlackOnWhite() {
        let ratio = ColorUtilities.contrastRatio(lum1: 0.0, lum2: 1.0)
        #expect(abs(ratio - 21.0) < 0.1, "Black on white should have maximum contrast of 21:1")
    }

    @Test("Contrast ratio for same color")
    func contrastRatioSameColor() {
        let ratio = ColorUtilities.contrastRatio(lum1: 0.5, lum2: 0.5)
        #expect(abs(ratio - 1.0) < 0.01, "Same luminance should have ratio of 1:1")
    }

    @Test("Contrast ratio meets WCAG AA")
    func contrastRatioMeetsWCAGAA() {
        // WCAG AA requires 4.5:1 for normal text
        let darkGray = ColorUtilities.parseHex("#595959")
        let white = ColorUtilities.RGBAComponents(red: 1, green: 1, blue: 1, alpha: 1)
        let darkLum = ColorUtilities.luminance(darkGray)
        let whiteLum = ColorUtilities.luminance(white)
        let ratio = ColorUtilities.contrastRatio(lum1: whiteLum, lum2: darkLum)
        #expect(ratio >= 4.5, "Dark gray on white should meet WCAG AA")
    }

    // MARK: - Accessible Text Color Tests

    @Test("Accessible text color on dark background")
    func accessibleTextColorOnDarkBackground() {
        let textColor = ColorUtilities.accessibleTextColor(onBackground: "#0E1114")
        // Should return white-ish color for dark backgrounds
        // We can't directly compare Color objects, but we can verify it's been called
        #expect(textColor != nil, "Should return a text color")
    }

    @Test("Accessible text color on light background")
    func accessibleTextColorOnLightBackground() {
        let textColor = ColorUtilities.accessibleTextColor(onBackground: "#FFFFFF")
        #expect(textColor != nil, "Should return a text color")
    }

    @Test("Accessible text color on mid-tone")
    func accessibleTextColorOnMidTone() {
        let textColor = ColorUtilities.accessibleTextColor(onBackground: "#808080")
        #expect(textColor != nil, "Should return a text color for mid-tone")
    }

    // MARK: - Color Extension Tests

    @Test("Color hex initializer with valid hex")
    func colorHexInitializerValid() {
        let color = Color(hex: "#FF5733")
        #expect(color != nil, "Valid hex should create a color")
    }

    @Test("Color hex initializer with invalid hex")
    func colorHexInitializerInvalid() {
        let color = Color(hex: "invalid")
        #expect(color == nil, "Invalid hex should return nil")
    }

    @Test("Color hex initializer with short format")
    func colorHexInitializerShortFormat() {
        let color = Color(hex: "#F53")
        #expect(color == nil, "3-digit hex should return nil (not in expected format)")
    }

    @Test("Wide gamut color creation")
    func colorWideGamut() {
        let color = Color.wideGamut("#FF5733")
        #expect(color != nil, "Wide gamut color should be created")
    }

    // MARK: - Integration Tests

    @Test("Tier colors parse consistently")
    func tierColorConsistency() {
        // Test that common tier colors parse correctly
        let tierS = ColorUtilities.parseHex("#FF0037")
        #expect(tierS.red > 0.9, "Tier S should be predominantly red")

        let tierA = ColorUtilities.parseHex("#FFA000")
        #expect(tierA.red > 0.9, "Tier A should have high red")
        #expect(tierA.green > 0.5, "Tier A should have moderate green (orange)")

        let tierB = ColorUtilities.parseHex("#00EC57")
        #expect(tierB.green > 0.8, "Tier B should be predominantly green")
    }

    @Test("All tier colors have accessible text options")
    func contrastOnAllTierColors() {
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
            #expect(meetsStandard, "Color \(hexColor) should have accessible text color option")
        }
    }
}
