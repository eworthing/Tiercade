import SwiftUI

/// Theme configurations for tier list color schemes
/// Provides curated color palettes following tvOS design guidelines
enum TierTheme: String, CaseIterable, Identifiable, Sendable {
    case smashClassic
    case heatmapGradient
    case pastel
    case monochrome
    case rainbow
    case darkNeon
    case nord

    var id: String { rawValue }

    /// Human-readable display name for the theme
    var displayName: String {
        switch self {
        case .smashClassic: return "Smash Classic"
        case .heatmapGradient: return "Heatmap Gradient"
        case .pastel: return "Pastel"
        case .monochrome: return "Monochrome"
        case .rainbow: return "Rainbow"
        case .darkNeon: return "Dark Neon"
        case .nord: return "Nord"
        }
    }

    /// Short description of the theme's visual style
    var description: String {
        switch self {
        case .smashClassic: return "Classic tier list colors"
        case .heatmapGradient: return "Heat intensity gradient"
        case .pastel: return "Soft, muted tones"
        case .monochrome: return "Grayscale spectrum"
        case .rainbow: return "Full color spectrum"
        case .darkNeon: return "Vibrant neon on dark"
        case .nord: return "Scandinavian palette"
        }
    }

    /// Returns the hex color string for a given tier identifier
    /// - Parameter tier: The tier identifier (e.g., "S", "A", "B")
    /// - Returns: Hex color string including # prefix
    func color(for tier: String) -> String {
        switch self {
        // 1. Smash Classic
        case .smashClassic:
            switch tier.lowercased() {
            case "s": return "#FF0000"
            case "a": return "#FF8000"
            case "b": return "#FFFF00"
            case "c": return "#00FF00"
            case "d": return "#0000FF"
            case "f": return "#808080"
            case "unranked": return "#6B7280"
            default: return "#000000"
            }

        // 2. Heatmap Gradient
        case .heatmapGradient:
            switch tier.lowercased() {
            case "s": return "#FF0000"
            case "a": return "#FF8000"
            case "b": return "#FFFF00"
            case "c": return "#00FF00"
            case "d": return "#0080FF"
            case "f": return "#8000FF"
            case "unranked": return "#808080"
            default: return "#000000"
            }

        // 3. Pastel
        case .pastel:
            switch tier.lowercased() {
            case "s": return "#FFB3BA"
            case "a": return "#FFDFBA"
            case "b": return "#FFFFBA"
            case "c": return "#BAFFC9"
            case "d": return "#BAE1FF"
            case "f": return "#E2E2E2"
            case "unranked": return "#CCCCCC"
            default: return "#000000"
            }

        // 4. Monochrome
        case .monochrome:
            switch tier.lowercased() {
            case "s": return "#000000"
            case "a": return "#4C4C4C"
            case "b": return "#7F7F7F"
            case "c": return "#B3B3B3"
            case "d": return "#CCCCCC"
            case "f": return "#FFFFFF"
            case "unranked": return "#808080"
            default: return "#000000"
            }

        // 5. Rainbow
        case .rainbow:
            switch tier.lowercased() {
            case "s": return "#FF0000"
            case "a": return "#FF8000"
            case "b": return "#FFFF00"
            case "c": return "#00FF00"
            case "d": return "#0000FF"
            case "f": return "#8B00FF"
            case "unranked": return "#808080"
            default: return "#000000"
            }

        // 6. Dark Neon
        case .darkNeon:
            switch tier.lowercased() {
            case "s": return "#FF2A6D"
            case "a": return "#FF7A00"
            case "b": return "#FFD300"
            case "c": return "#39FF14"
            case "d": return "#00E5FF"
            case "f": return "#7C00FF"
            case "unranked": return "#374151"
            default: return "#000000"
            }

        // 7. Nord
        case .nord:
            switch tier.lowercased() {
            case "s": return "#BF616A"
            case "a": return "#D08770"
            case "b": return "#EBCB8B"
            case "c": return "#A3BE8C"
            case "d": return "#88C0D0"
            case "f": return "#5E81AC"
            case "unranked": return "#4C566A"
            default: return "#000000"
            }
        }
    }

    /// Returns a SwiftUI Color for the given tier
    /// - Parameter tier: The tier identifier
    /// - Returns: SwiftUI Color instance
    func swiftUIColor(for tier: String) -> Color {
        ColorUtilities.color(hex: color(for: tier))
    }
}
