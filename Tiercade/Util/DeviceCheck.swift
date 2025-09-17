import Foundation

enum DeviceCheck {
    static var isLowMemoryTV: Bool {
        // Very rough placeholder: Apple TV HD devices are older; refine if needed
        // Since we don't have UIDevice on tvOS publicly exposing model identifiers, use OS version as proxy
        #if os(tvOS)
        return false
        #else
        return false
        #endif
    }
}
