import Foundation
import SwiftUI

// Common UI support types (available regardless of core package presence)
// MARK: - Filter Types
public enum FilterType: String, CaseIterable {
    case all = "All"
    case ranked = "Ranked"
    case unranked = "Unranked"
}

// MARK: - Toast System

internal enum ToastType {
    case success
    case error
    case info
    case warning

    internal var color: Color {
        switch self {
        case .success:
            return .green
        case .error:
            return .red
        case .info:
            return .blue
        case .warning:
            return .orange
        }
    }

    internal var icon: String {
        switch self {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        }
    }
}

internal struct ToastMessage: Identifiable {
    internal let id = UUID()
    internal let type: ToastType
    internal let title: String
    internal let message: String?
    internal let duration: TimeInterval
    internal let actionTitle: String?
    internal let action: (() -> Void)?

    init(
        type: ToastType,
        title: String,
        message: String? = nil,
        duration: TimeInterval = 3.0,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
        self.actionTitle = actionTitle
        self.action = action
    }
}

// Use the canonical core package types directly - no TL-prefixed fallbacks or
// typealias shims. This file retains a small, explicit extension on the core
// Item to provide a convenient attributes bag for code that prefers that view
// of the model, but we do not create alias types or TL* fallbacks.

// Intentionally keep this file focused on UI helpers and small app-only types.
// The compatibility extensions that exposed a legacy `attributes` bag and
// aliases for `season`/`thumbUri` have been removed in favor of using the
// canonical `TiercadeCore.Item` API directly (name, seasonString/seasonNumber,
// imageUrl, videoUrl, etc.). This repository is in a migration phase and the
// app code has been updated to reference the canonical fields.

// MARK: - Color helpers
// Note: Basic hex parsing for backward compatibility. Full color utilities in ColorUtilities.swift
internal extension Color {
    init?(hex: String) {
        internal var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        internal let r = Double((v >> 16) & 0xFF) / 255.0
        internal let g = Double((v >> 8) & 0xFF) / 255.0
        internal let b = Double(v & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
