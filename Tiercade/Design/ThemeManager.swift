import SwiftUI

internal enum ThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    internal var id: String { rawValue }

    internal var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
