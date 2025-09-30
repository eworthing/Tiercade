import Foundation
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
        let formatted = [
            "[AppState] setLoading:",
            "loading=\(isLoading)",
            "message=\(message)",
            "progress=\(operationProgress)"
        ].joined(separator: " ")
        print(formatted)
        NSLog("%@", formatted)
    }

    private func logDragTarget(_ tierName: String?) {
        let value = tierName ?? "nil"
        let message = "[AppState] setDragTarget: \(value)"
        print(message)
        NSLog("%@", message)
    }

    private func logDragging(_ id: String?) {
        let value = id ?? "nil"
        let message = "[AppState] setDragging: \(value)"
        print(message)
        NSLog("%@", message)
    }
}
