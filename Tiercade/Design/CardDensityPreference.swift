import Foundation
import SwiftUI

enum CardDensityPreference: String, CaseIterable, Identifiable, Codable, Sendable {
    case ultraMicro
    case micro
    case tight
    case compact
    case standard
    case expanded

    // MARK: Internal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .ultraMicro:
            "Ultra Micro"
        case .micro:
            "Micro"
        case .tight:
            "Tight"
        case .compact:
            "Compact"
        case .standard:
            "Standard"
        case .expanded:
            "Expanded"
        }
    }

    var detailDescription: String {
        switch self {
        case .ultraMicro:
            "Image-only posters"
        case .micro:
            "Ultra tight cards with minimal text"
        case .tight:
            "Packs a few more cards"
        case .compact:
            "Shows more cards per row"
        case .standard:
            "Balanced card size"
        case .expanded:
            "Largest cards for visibility"
        }
    }

    var symbolName: String {
        switch self {
        case .ultraMicro:
            "square.grid.4x3.fill"
        case .micro:
            "square.grid.3x3.fill"
        case .tight:
            "rectangle.grid.3x2.fill"
        case .compact:
            "rectangle.grid.3x2"
        case .standard:
            "rectangle.grid.2x2"
        case .expanded:
            "rectangle.grid.2x2.fill"
        }
    }

    var focusTooltip: String {
        switch self {
        case .ultraMicro:
            "Ultra Micro Cards"
        case .micro:
            "Micro Cards"
        case .tight:
            "Tight Cards"
        case .compact:
            "Compact Cards"
        case .standard:
            "Standard Cards"
        case .expanded:
            "Expanded Cards"
        }
    }

    var toastMessage: String {
        switch self {
        case .ultraMicro:
            "Ultra Micro card layout enabled"
        case .micro:
            "Micro card layout enabled"
        case .tight:
            "Tight card layout enabled"
        case .compact:
            "Compact card layout enabled"
        case .standard:
            "Standard card layout enabled"
        case .expanded:
            "Expanded card layout enabled"
        }
    }

    var sizeRank: Int {
        switch self {
        case .ultraMicro: 0
        case .micro: 1
        case .tight: 2
        case .compact: 3
        case .standard: 4
        case .expanded: 5
        }
    }

    var showsOnCardText: Bool {
        switch self {
        case .ultraMicro:
            false
        default:
            true
        }
    }

    func next() -> CardDensityPreference {
        let all = CardDensityPreference.allCases
        guard let currentIndex = all.firstIndex(of: self) else {
            return .ultraMicro
        }
        let nextIndex = all.index(after: currentIndex)
        return nextIndex < all.endIndex ? all[nextIndex] : all.first ?? .ultraMicro
    }

}
