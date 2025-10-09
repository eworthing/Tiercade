import Foundation
import os
import TiercadeCore

@MainActor
extension AppState {
    // MARK: - Loading & Progress
    func setLoading(_ loading: Bool, message: String = "") {
        isLoading = loading
        loadingMessage = message
        if loading {
            operationProgress = 0.0
        }
        logLoadingState(isLoading: loading, message: message)
    }

    func updateProgress(_ progress: Double) {
        operationProgress = min(max(progress, 0.0), 1.0)
    }

    func setDragTarget(_ tierName: String?) {
        dragTargetTier = tierName
        logDragTarget(tierName)
    }

    func setDragging(_ id: String?) {
        draggingId = id
        logDragging(id)
    }

    func setSearchProcessing(_ processing: Bool) {
        isProcessingSearch = processing
    }

    func withLoadingIndicator<T: Sendable>(message: String, operation: () async throws -> T) async rethrows -> T {
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
