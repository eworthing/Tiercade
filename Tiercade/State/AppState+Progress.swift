import Foundation
import os
import TiercadeCore

@MainActor
internal extension AppState {
    // MARK: - Loading & Progress
    func setLoading(_ loading: Bool, message: String = "") {
        progress.setLoading(loading, message: message)
    }

    func updateProgress(_ progressValue: Double) {
        progress.updateProgress(progressValue)
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

    private func logDragTarget(_ tierName: String?) {
        Logger.appState.debug("Drag target: \(tierName ?? "nil")")
    }

    private func logDragging(_ id: String?) {
        Logger.appState.debug("Dragging: \(id ?? "nil")")
    }
}
