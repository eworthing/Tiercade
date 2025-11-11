import Foundation

internal enum DeviceCheck {
    internal static var isLowMemoryTV: Bool {
        // Only applicable on tvOS. Return false there (no low-memory gating by default).
        // On non-tvOS platforms, return true to ensure this flag is never used to
        // gate non-TV code paths by mistake.
        #if os(tvOS)
        return false
        #else
        return true
        #endif
    }
}
