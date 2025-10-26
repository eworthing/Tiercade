import Foundation
import os
import TiercadeCore

@MainActor
internal extension AppState {
    // MARK: - Loading & Progress
    internal func setLoading(_ loading: Bool, message: String = "") {
        isLoading = loading
        loadingMessage = message
        if loading {
            operationProgress = 0.0
        }
        logLoadingState(isLoading: loading, message: message)
    }

    internal func updateProgress(_ progress: Double) {
        operationProgress = min(max(progress, 0.0), 1.0)
    }

    internal func setDragTarget(_ tierName: String?) {
        dragTargetTier = tierName
        logDragTarget(tierName)
    }

    internal func setDragging(_ id: String?) {
        draggingId = id
        logDragging(id)
    }

    internal func setSearchProcessing(_ processing: Bool) {
        isProcessingSearch = processing
    }

    internal func withLoadingIndicator<T: Sendable>(message: String, operation: () async throws -> T) async rethrows -> T {
        setLoading(true, message: message)
        defer { setLoading(false) }
        return try await operation()
    }

    private func logLoadingState(isLoading: Bool, message: String) {
        Logger.appState.debug("Loading: \(isLoading) message=\(message) progress=\(self.operationProgress)")
    }

    private func logDragTarget(_ tierName: String?) {
        Logger.appState.debug("Drag target: \(tierName ?? "nil")")
    }

    private func logDragging(_ id: String?) {
        Logger.appState.debug("Dragging: \(id ?? "nil")")
    }
}
