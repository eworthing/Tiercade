import Foundation
import SwiftUI
import Observation
import os

/// Consolidated state for loading indicators and progress tracking
///
/// This state object encapsulates all progress-related state including:
/// - Loading state (isLoading, loadingMessage)
/// - Progress tracking (operationProgress)
/// - Helper methods for progress management
@MainActor
@Observable
internal final class ProgressState {
    // MARK: - Loading State

    /// Whether a long-running operation is currently in progress
    internal var isLoading: Bool = false

    /// Message describing the current loading operation
    internal var loadingMessage: String = ""

    /// Progress of the current operation (0.0 to 1.0)
    internal var operationProgress: Double = 0.0

    // MARK: - Initialization

    internal init() {
        Logger.appState.info("ProgressState initialized")
    }

    // MARK: - Loading Management

    /// Set the loading state with an optional message
    internal func setLoading(_ loading: Bool, message: String = "") {
        isLoading = loading
        loadingMessage = message
        if loading {
            operationProgress = 0.0
        }
        logLoadingState(isLoading: loading, message: message)
    }

    /// Update the progress of the current operation (clamped to 0.0-1.0)
    internal func updateProgress(_ progress: Double) {
        operationProgress = min(max(progress, 0.0), 1.0)
    }

    /// Reset all progress state to defaults
    internal func reset() {
        isLoading = false
        loadingMessage = ""
        operationProgress = 0.0
    }

    // MARK: - Logging

    private func logLoadingState(isLoading: Bool, message: String) {
        Logger.appState.debug("Loading: \(isLoading) message=\(message) progress=\(self.operationProgress)")
    }
}
