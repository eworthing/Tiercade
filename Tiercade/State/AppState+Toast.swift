import Foundation
import SwiftUI
import TiercadeCore

@MainActor
internal extension AppState {
    // MARK: - Toast System

    internal func showToast(type: ToastType, title: String, message: String? = nil, duration: TimeInterval = 3.0) {
        let toast = ToastMessage(type: type, title: title, message: message, duration: duration)
        currentToast = toast
        logEvent("showToast: type=\(type) title=\(title) message=\(message ?? "") duration=\(duration)")

        // Auto-dismiss after duration using structured concurrency
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if self.currentToast?.id == toast.id {
                self.dismissToast()
            }
        }
    }

    internal func dismissToast() {
        currentToast = nil
        logEvent("dismissToast")
    }

    internal func showSuccessToast(_ title: String, message: String? = nil) {
        showToast(type: .success, title: title, message: message)
    }

    internal func showErrorToast(_ title: String, message: String? = nil) {
        showToast(type: .error, title: title, message: message)
    }

    internal func showInfoToast(_ title: String, message: String? = nil) {
        showToast(type: .info, title: title, message: message)
    }

    internal func showWarningToast(_ title: String, message: String? = nil) {
        showToast(type: .warning, title: title, message: message)
    }

    internal func showToast(type: ToastType, title: String, message: String?) {
        showToast(type: type, title: title, message: message, duration: 3.0)
    }
}
