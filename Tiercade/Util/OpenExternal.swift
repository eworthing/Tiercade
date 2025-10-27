import Foundation
import SwiftUI
#if os(macOS)
import AppKit
#endif
#if os(iOS)
import UIKit
#endif

internal enum ExternalOpenResult { case success, handoff, unsupported }

internal struct OpenExternal {
    internal static func open(_ url: URL, completion: @escaping @MainActor (ExternalOpenResult) -> Void) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        Task { @MainActor in
            completion(.success)
        }
        #elseif os(iOS)
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
