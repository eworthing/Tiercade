import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

internal enum ExternalOpenResult { case success, handoff, unsupported }

internal struct OpenExternal {
    internal static func open(_ url: URL, completion: @escaping @MainActor (ExternalOpenResult) -> Void) {
        #if canImport(UIKit)
        UIApplication.shared.open(url) { ok in
            Task { @MainActor in
                completion(ok ? .success : .unsupported)
            }
        }
        #else
        Task { @MainActor in
            completion(.unsupported)
        }
        #endif
    }
}
