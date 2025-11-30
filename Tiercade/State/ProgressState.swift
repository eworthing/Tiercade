import Foundation
import Observation
import os
import SwiftUI

/// Consolidated state for loading indicators and progress tracking
///
/// This state object encapsulates all progress-related state including:
/// - Loading state (isLoading, loadingMessage)
/// - Progress tracking (operationProgress)
/// - Helper methods for progress management
@MainActor
@Observable
final class ProgressState {
    // MARK: - Loading State

    /// Whether a long-running operation is currently in progress
    var isLoading: Bool = false

    /// Message describing the current loading operation
    var loadingMessage: String = ""

    /// Progress of the current operation (0.0 to 1.0)
    var operationProgress: Double = 0.0

    // MARK: - Initialization

    init() {
        Logger.appState.info("ProgressState initialized")
    }

    // MARK: - Loading Management

    /// Set the loading state with an optional message
    func setLoading(_ loading: Bool, message: String = "") {
        isLoading = loading
        loadingMessage = message
        if loading {
            operationProgress = 0.0
        }
        logLoadingState(isLoading: loading, message: message)
    }

    /// Update the progress of the current operation (clamped to 0.0-1.0)
    func updateProgress(_ progress: Double) {
        operationProgress = min(max(progress, 0.0), 1.0)
    }

    /// Reset all progress state to defaults
    func reset() {
        isLoading = false
        loadingMessage = ""
        operationProgress = 0.0
    }

    // MARK: - Logging

    private func logLoadingState(isLoading: Bool, message: String) {
        Logger.appState.debug("Loading: \(isLoading) message=\(message) progress=\(operationProgress)")
    }
}
