import Foundation
import Testing
@testable import TiercadeCore

// MARK: - RandomUtilsTests

@Suite("RandomUtils")
struct RandomUtilsTests {
    @Test("Seeded RNG yields deterministic sequences")
    func seededRNGDeterministic() {
        var rngA = SeededRNG(seed: 42)
        var rngB = SeededRNG(seed: 42)

        for _ in 0 ..< 5 {
            #expect(rngA.next() == rngB.next())
        }
    }

    @Test("Seed normalization avoids zero-state lock")
    func seededRNGNormalizesZero() {
        var rng = SeededRNG(seed: 0)
        let first = rng.next()
        #expect(first > 0)
    }

    @Test("pickRandomPair returns nil for insufficient elements")
    func pickRandomPairRequiresTwo() {
        let pair = RandomUtils.pickRandomPair([1], rng: { 0.5 })
        #expect(pair == nil)
    }

    @Test("pickRandomPair rerolls duplicate index")
    func pickRandomPairRerollsDuplicateIndex() {
        let sequence = SequenceRNG([0.0, 0.0])
        let pair = RandomUtils.pickRandomPair(["a", "b", "c"], rng: { sequence.next() })
        #expect(pair?.0 == "a")
        #expect(pair?.1 == "b")
    }
}

// MARK: - SequenceRNG

private final class SequenceRNG {
    private let values: [Double]
    private var index = 0

    init(_ values: [Double]) {
        precondition(!values.isEmpty, "SequenceRNG requires at least one value")
        self.values = values
    }

    func next() -> Double {
        defer { index = (index + 1) % values.count }
        return values[index]
    }
}
