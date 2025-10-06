import Foundation
import SwiftUI

enum CardDensityPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case ultraMicro
    case micro
    case tight
    case compact
    case standard
    case expanded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ultraMicro:
            return "Ultra Micro"
        case .micro:
            return "Micro"
        case .tight:
            return "Tight"
        case .compact:
            return "Compact"
        case .standard:
            return "Standard"
        case .expanded:
            return "Expanded"
        }
    }

    var detailDescription: String {
        switch self {
        case .ultraMicro:
            return "Image-only posters"
        case .micro:
            return "Ultra tight cards with minimal text"
        case .tight:
            return "Packs a few more cards"
        case .compact:
            return "Shows more cards per row"
        case .standard:
            return "Balanced card size"
        case .expanded:
            return "Largest cards for visibility"
        }
    }

    var symbolName: String {
        switch self {
        case .ultraMicro:
            return "square.grid.4x3.fill"
        case .micro:
            return "square.grid.3x3.fill"
        case .tight:
            return "rectangle.grid.3x2.fill"
        case .compact:
            return "rectangle.grid.3x2"
        case .standard:
            return "rectangle.grid.2x2"
        case .expanded:
            return "rectangle.grid.2x2.fill"
        }
    }

    var focusTooltip: String {
        switch self {
        case .ultraMicro:
            return "Ultra Micro Cards"
        case .micro:
            return "Micro Cards"
        case .tight:
            return "Tight Cards"
        case .compact:
            return "Compact Cards"
        case .standard:
            return "Standard Cards"
        case .expanded:
            return "Expanded Cards"
        }
    }

    var toastMessage: String {
        switch self {
        case .ultraMicro:
            return "Ultra Micro card layout enabled"
        case .micro:
            return "Micro card layout enabled"
        case .tight:
            return "Tight card layout enabled"
        case .compact:
            return "Compact card layout enabled"
        case .standard:
            return "Standard card layout enabled"
        case .expanded:
            return "Expanded card layout enabled"
        }
    }

    func next() -> CardDensityPreference {
        let all = CardDensityPreference.allCases
        guard let currentIndex = all.firstIndex(of: self) else { return .ultraMicro }
        let nextIndex = all.index(after: currentIndex)
        return nextIndex < all.endIndex ? all[nextIndex] : all.first ?? .ultraMicro
    }

    var sizeRank: Int {
        switch self {
        case .ultraMicro: return 0
        case .micro: return 1
        case .tight: return 2
        case .compact: return 3
        case .standard: return 4
        case .expanded: return 5
        }
    }

    var showsOnCardText: Bool {
        switch self {
        case .ultraMicro:
            return false
        default:
            return true
        }
    }
}
