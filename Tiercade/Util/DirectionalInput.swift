import SwiftUI

/// Shared directional movement abstraction that bridges Siri Remote move commands and hardware keyboard arrows.
enum DirectionalMove {
    case left
    case right
    case up
    case down

    #if os(tvOS)
    /// Maps `MoveCommandDirection` (available on tvOS/macOS family) to the shared directional enum.
    init?(moveCommand: MoveCommandDirection) {
        switch moveCommand {
        case .left: self = .left
        case .right: self = .right
        case .up: self = .up
        case .down: self = .down
        @unknown default:
            return nil
        }
    }
    #endif

    #if !os(tvOS)
    /// Maps keyboard arrow key equivalents to the shared directional enum.
    init?(keyEquivalent: KeyEquivalent) {
        switch keyEquivalent {
        case .upArrow: self = .up
        case .downArrow: self = .down
        case .leftArrow: self = .left
        case .rightArrow: self = .right
        default:
            return nil
        }
    }
    #endif
}
