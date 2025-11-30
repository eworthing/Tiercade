import Foundation

// MARK: - Wilson Score Interval Utilities

extension HeadToHeadLogic {
    /// Calculates the lower bound of a Wilson score interval for integer counts
    /// Used for conservative probability estimation with small sample sizes
    static func wilsonLowerBound(wins: Int, total: Int, z: Double) -> Double {
        guard total > 0 else {
            return 0
        }
        let p = Double(wins) / Double(total)
        let z2 = z * z
        let denominator = 1.0 + z2 / Double(total)
        let center = p + z2 / (2.0 * Double(total))
        let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * Double(total))) / Double(total))
        return max(0, (center - margin) / denominator)
    }

    /// Calculates the upper bound of a Wilson score interval for integer counts
    static func wilsonUpperBound(wins: Int, total: Int, z: Double) -> Double {
        guard total > 0 else {
            return 0
        }
        let p = Double(wins) / Double(total)
        let z2 = z * z
        let denominator = 1.0 + z2 / Double(total)
        let center = p + z2 / (2.0 * Double(total))
        let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * Double(total))) / Double(total))
        return min(1, (center + margin) / denominator)
    }

    /// Calculates the lower bound of a Wilson score interval for floating-point counts
    /// Used when wins/total may be fractional (e.g., with Bayesian priors)
    static func wilsonLowerBoundD(wins: Double, total: Double, z: Double) -> Double {
        guard total > 0 else {
            return 0
        }
        let p = wins / total
        let z2 = z * z
        let denominator = 1.0 + z2 / total
        let center = p + z2 / (2.0 * total)
        let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * total)) / total)
        return max(0, (center - margin) / denominator)
    }

    /// Calculates the upper bound of a Wilson score interval for floating-point counts
    static func wilsonUpperBoundD(wins: Double, total: Double, z: Double) -> Double {
        guard total > 0 else {
            return 0
        }
        let p = wins / total
        let z2 = z * z
        let denominator = 1.0 + z2 / total
        let center = p + z2 / (2.0 * total)
        let margin = z * sqrt((p * (1.0 - p) + z2 / (4.0 * total)) / total)
        return min(1, (center + margin) / denominator)
    }
}
