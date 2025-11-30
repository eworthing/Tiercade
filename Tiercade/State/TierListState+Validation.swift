import Foundation
import os
import TiercadeCore

extension TierListState {
    /// Validates critical tier system invariants.
    ///
    /// This method checks for violations of the tier structure contract that could
    /// cause runtime failures or data corruption. In DEBUG builds, violations trigger
    /// assertions; in RELEASE builds, they are logged as errors.
    ///
    /// **Invariants checked:**
    /// 1. Reserved tier "unranked" must NEVER appear in tierOrder
    /// 2. Reserved tier "unranked" must ALWAYS exist in tiers dictionary
    /// 3. All tiers in tierOrder must have corresponding entries in tiers (even if empty)
    ///
    /// - Returns: Array of violation messages (empty if all invariants hold)
    @MainActor
    func validateTierInvariants() -> [String] {
        var violations: [String] = []
        let unrankedKey = TierIdentifier.unranked.rawValue

        // INVARIANT 1: "unranked" must never be in tierOrder
        if tierOrder.contains(unrankedKey) {
            let message = "FATAL: Reserved tier '\(unrankedKey)' found in tierOrder"
            violations.append(message)
            Logger.appState.error("\(message)")
            assertionFailure(message)
        }

        // INVARIANT 2: "unranked" must always exist in tiers
        if tiers[unrankedKey] == nil {
            let message = "FATAL: Reserved tier '\(unrankedKey)' missing from tiers dictionary"
            violations.append(message)
            Logger.appState.error("\(message)")
            assertionFailure(message)
        }

        // INVARIANT 3: All tierOrder entries must exist in tiers (prevents dangling tier names)
        for tierName in tierOrder where tiers[tierName] == nil {
            let message = "WARNING: Tier '\(tierName)' in tierOrder has no tiers entry"
            violations.append(message)
            Logger.appState.warning("\(message)")
        }

        if violations.isEmpty {
            Logger.appState.debug("Tier invariants validated: OK")
        } else {
            Logger.appState.error("Tier invariants validation failed: \(violations.count) violation(s)")
        }

        return violations
    }

    /// Validates tier invariants and logs violations (convenience method).
    ///
    /// Use this in DEBUG builds after any operation that mutates tier structure:
    /// - Adding/removing tiers
    /// - Reordering tierOrder
    /// - Importing tier data
    /// - Applying bundled projects
    ///
    /// Example:
    /// ```swift
    /// tierList.tiers = newTiers
    /// #if DEBUG
    /// tierList.validateAndLog()
    /// #endif
    /// ```
    @MainActor
    func validateAndLog() {
        let violations = validateTierInvariants()
        if !violations.isEmpty {
            Logger.appState.error("Tier validation failed with \(violations.count) violations")
            for violation in violations {
                Logger.appState.error("  - \(violation)")
            }
        }
    }
}
