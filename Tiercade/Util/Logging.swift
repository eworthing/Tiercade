//
//  Logging.swift
//  Tiercade
//
//  Unified logging system using Swift's os.Logger
//  Provides subsystem-scoped loggers for different app domains
//

import Foundation
import os

/// Centralized logging infrastructure using Swift's unified logging system.
///
/// Usage:
/// ```swift
/// Logger.appState.info("Tier moved: \(itemId) → \(tierName)")
/// Logger.headToHead.debug("Queue size: \(pairsQueue.count)")
/// Logger.persistence.error("Save failed: \(error)")
/// ```
///
/// Benefits:
/// - Automatic integration with Console.app for debugging
/// - Privacy-aware logging (sensitive data redacted by default)
/// - Log levels (debug, info, notice, error, fault)
/// - Subsystem/category filtering
/// - Zero performance cost when logging disabled
extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.tiercade.app"

    /// General application state changes and lifecycle events
    internal static let appState = Logger(subsystem: subsystem, category: "AppState")

    /// Head-to-Head matchup system logs
    internal static let headToHead = Logger(subsystem: subsystem, category: "HeadToHead")

    /// Persistence, save, and load operations
    internal static let persistence = Logger(subsystem: subsystem, category: "Persistence")

    /// Export operations (JSON, CSV, PNG, PDF)
    internal static let export = Logger(subsystem: subsystem, category: "Export")

    /// Import operations and data parsing
    internal static let dataImport = Logger(subsystem: subsystem, category: "Import")

    /// Item management (add, delete, move)
    internal static let items = Logger(subsystem: subsystem, category: "Items")

    /// Theme and UI customization
    internal static let theme = Logger(subsystem: subsystem, category: "Theme")

    /// Selection and multi-select operations
    internal static let selection = Logger(subsystem: subsystem, category: "Selection")

    /// Analysis and statistics
    internal static let analysis = Logger(subsystem: subsystem, category: "Analysis")

    /// Search operations
    internal static let search = Logger(subsystem: subsystem, category: "Search")
}
