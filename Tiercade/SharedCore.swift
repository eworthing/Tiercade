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

enum ToastType {
    case success
    case error
    case info
    case warning

    var color: Color {
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

    var icon: String {
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

struct ToastMessage: Identifiable {
    let id = UUID()
    let type: ToastType
    let title: String
    let message: String?
    let duration: TimeInterval
    let actionTitle: String?
    let action: (() -> Void)?

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

// Use the canonical core package types directly — no TL‑prefixed fallbacks or
// typealias shims. Intentionally keep this file focused on UI helpers and
// small app‑only types.

// Notes on attributes: The convenience `init(id:attributes:)` that accepts a
// generic attributes bag now lives in TiercadeCore.Item (see
// TiercadeCore/Sources/TiercadeCore/Models/Models.swift). We do not add any
// Item extensions here. App code should reference the canonical Item fields
// (name, seasonString/seasonNumber, imageUrl, videoUrl, etc.) or use the
// core package initializer when mapping from loose dictionaries.

// MARK: - Color helpers
// Note: Basic hex parsing for backward compatibility. Full color utilities in ColorUtilities.swift
extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
