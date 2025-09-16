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

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let type: ToastType
    let title: String
    let message: String?
    let duration: TimeInterval

    init(type: ToastType, title: String, message: String? = nil, duration: TimeInterval = 3.0) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
    }
}

// Use the canonical core package types directly - no TL-prefixed fallbacks or
// typealias shims. This file retains a small, explicit extension on the core
// Item to provide a convenient attributes bag for code that prefers that view
// of the model, but we do not create alias types or TL* fallbacks.

import TiercadeCore

// Provide a small TierListSaveData type so AppState's save/load helpers keep working.
public struct TierListSaveData: Codable {
    public let tiers: TiercadeCore.Items
    public let createdDate: Date
    public let appVersion: String

    public init(tiers: TiercadeCore.Items, createdDate: Date, appVersion: String) {
        self.tiers = tiers
        self.createdDate = createdDate
        self.appVersion = appVersion
    }
}

// Extend the core Item to expose a legacy-style attributes bag and some
// convenience properties used by the app UI. This is a targeted compatibility
// surface (not a typealias/shim) to ease migration of callers to the canonical
// Item's typed properties.
// Extend the core Item directly (no local typealias). This exposes a
// small, legacy-compatible attributes bag and a few convenience accessors
// used by the app UI during migration. Call sites should import
// `TiercadeCore` and reference the canonical types directly.
public extension TiercadeCore.Item {
    // Backwards-compatible attributes bag (computed)
    var attributes: [String: String]? {
        get {
            var dict: [String: String] = [:]
            if let n = name { dict["name"] = n }
            if let s = seasonString { dict["season"] = s }
            if let sn = seasonNumber { dict["seasonNumber"] = String(sn) }
            if let img = imageUrl { dict["imageUrl"] = img }
            if let v = videoUrl { dict["videoUrl"] = v }
            if let st = status { dict["status"] = st }
            if let d = description { dict["description"] = d }
            return dict.isEmpty ? nil : dict
        }
        set {
            guard let a = newValue else {
                name = nil
                seasonString = nil
                seasonNumber = nil
                imageUrl = nil
                videoUrl = nil
                status = nil
                description = nil
                return
            }
            name = a["name"] ?? name
            if let sn = a["seasonNumber"], let n = Int(sn) {
                seasonNumber = n
                seasonString = String(n)
            } else if let s = a["season"] {
                seasonString = s
                seasonNumber = Int(s)
            }
            imageUrl = a["thumbUri"] ?? a["imageUrl"] ?? imageUrl
            videoUrl = a["videoUrl"] ?? videoUrl
            status = a["status"] ?? status
            description = a["description"] ?? description
        }
    }

    // Legacy-season property (string) used throughout the app
    var season: String? {
        get { seasonString }
        set { seasonString = newValue }
    }

    // Legacy thumbnail alias
    var thumbUri: String? {
        get { imageUrl }
        set { imageUrl = newValue }
    }
}
