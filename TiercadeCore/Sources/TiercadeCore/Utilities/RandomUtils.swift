import Foundation

// MARK: - SeededRNG

public struct SeededRNG: Sendable {
    private var state: Int32
    public init(seed: Int) {
        var s = Int32(abs(seed) % 2_147_483_647)
        if s == 0 {
            s = 1
        }
        self.state = s
    }

    public mutating func next() -> Double {
        // 32-bit Lehmer LCG (MINSTD)
        let a: Int32 = 16807
        let m: Int32 = 2_147_483_647
        let prod = Int64(state) * Int64(a)
        state = Int32(prod % Int64(m))
        return Double(state - 1) / Double(m - 1)
    }
}

// MARK: - RandomUtils

public enum RandomUtils {
    public static func pickRandomPair<T>(_ arr: [T], rng: () -> Double) -> (T, T)? {
        let pool = arr
        guard pool.count >= 2 else {
            return nil
        }
        let i = Int(floor(rng() * Double(pool.count)))
        var j = Int(floor(rng() * Double(pool.count)))
        if j == i {
            j = (j + 1) % pool.count
        }
        return (pool[i], pool[j])
    }
}
