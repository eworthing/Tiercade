# TiercadeCore

Core domain models and logic for the Tiercade native apps. This Swift Package
is platform-agnostic and intended to be used by iOS, iPadOS, macOS, and tvOS
apps.

## Public API surface & stability

| Component | Purpose | Stability notes |
| --- | --- | --- |
| `Item`, `Items`, `TierConfig` | Core data structures for tier modelling | **Stable** – schema changes trigger a MINOR bump; removing fields is MAJOR |
| `TierLogic` | Deterministic helpers for move/reorder/history | **Stable** – new helpers are additive; existing signatures kept backward-compatible |
| `HeadToHeadLogic` | Pair generation and voting maths | **Stable** – algorithm tweaks retain identical inputs → outputs guarantees |
| `RandomUtils` | Seedable random utilities | **Stable** – deterministic contract documented below |
| `ModelResolver` | Load and validate JSON resources | **Stable** – decoding rules described below |
| `ExportFormatter`, `AnalysisFormatter` | String/CSV formatting parity with web app | **Stable** – format changes require a MINOR bump |

## Requirements

- **Swift 6.0** toolchain with strict concurrency checking
- **Platforms**: iOS 26+ / macOS 26+ / tvOS 26+
- **Language Mode**: Swift 6 with complete concurrency checking enabled

> Note: The core package now shares the Tiercade app's OS 26.0+ baseline so we
> can rely on Swift 6 APIs, Liquid Glass effects, and strict concurrency across
> every module. We build with the Swift 6 language mode while using the Swift
> 6.2 toolchain (via `swift-tools-version: 6.2`), matching the configuration
> used by the main app target.

## Thread-safety & Sendable guarantees

TiercadeCore is UI-free, pure Swift, and is audited with Swift 6 strict
concurrency (`.enableUpcomingFeature("StrictConcurrency")` +
`-strict-concurrency=complete`). Public value types (`Item`, `TierConfig`, etc.)
conform to `Sendable`. The `SeededRNG` struct is also `Sendable` but uses
`mutating` methods—callers should use value semantics (copy-on-write) or
confine mutations to a single task to avoid shared mutable state.

## Using in Xcode

1. In your app project, go to File > Add Packages…
2. Choose Add Local, select the `TiercadeCore` folder
3. Add the library to your app target

## Quick sample

```swift
import TiercadeCore

// Load from Data
let project = try ModelResolver.decodeProject(from: Data(/* … */))
let items = project.items
let groups = project.groups

// Or load from URL
let projectFromFile = try ModelResolver.loadProject(from: url)

let tiers: Items = [
    "S": [],
    "A": [],
    "B": [],
    "C": [],
    "D": [],
    "F": [],
    "unranked": [Item(id: "x", attributes: ["name": "X"])]
]
let moved = TierLogic.moveItem(tiers, itemId: "x", targetTierName: "S")
```

## Usage cookbook

```swift
import TiercadeCore

// Decode from data or load from URL
let project = try ModelResolver.decodeProject(from: bundledData)
// Or: let project = try ModelResolver.loadProject(from: bundledURL)

var tiers = project.initialTiers()
// Happy path: move succeeds when id + tier exist.
tiers = TierLogic.moveItem(tiers, itemId: "baba", targetTierName: "A")

// Failure mode: returns unchanged set when id missing.
let unchanged = TierLogic.moveItem(tiers, itemId: "missing", targetTierName: "S")
assert(unchanged == tiers)
```

- `TierLogic.moveItem` and `TierLogic.moveItems` never throw; they return the
  original dictionary if the id/tier combination is invalid.
- `HeadToHeadLogic.initialComparisonQueueWarmStart` returns an empty array when
  fewer than two items are supplied or when target comparisons is zero—callers
  should check the queue length before proceeding.

## Deterministic utilities

- `SeededRNG` uses a Lehmer LCG (MINSTD); providing the same seed yields the
  same shuffle across app and tests.
- Seeding contract: `SeededRNG(seed: Int)` initializes the generator; tests can use fixture seeds (`12345`) safely.
- All random helpers are pure functions that take an `rng: () -> Double`
  closure; no global RNG is touched.

## Decoding contracts

- `ModelResolver` accepts either string or numeric `season` values; it stores
  both the raw string and optional numeric conversion.
- Unknown keys are preserved via `attributes` dictionaries rather than
  dropped, matching the TypeScript client.
- Required fields: `Item.id`, tier identifiers, and schema version.
  Missing required fields throw `ModelResolver.Error.invalidResource`.

## Tests

Swift Testing suites are checked in under `Tests/TiercadeCoreTests/`. Run tests with:

```bash
cd TiercadeCore
swift test
```

**Test coverage areas:**

- `HeadToHeadLogicTests.swift` - Pairwise comparison ranking algorithm
- `HeadToHeadInternalsTests.swift` - Wilson score and boundary logic
- `HeadToHeadSimulations.swift` - Monte Carlo validation (600+ simulations)
- `HeadToHeadParameterSweep.swift` - Budget and noise parameter analysis
- `HeadToHeadVarianceAnalysis.swift` - Consistency and stability tests
- `TierLogicTests.swift` - Tier move and reorder operations
- `QuickRankLogicTests.swift` - Quick ranking helpers
- `ModelResolverTests.swift` - JSON/data decoding validation
- `RandomUtilsTests.swift` - Seedable RNG determinism
- `FormattersTests.swift` - Export format output
- `ModelsTests.swift` - Core data model behavior
- `SortingTests.swift` - Sort algorithm correctness
- `DataLoaderTests.swift` - Resource loading
- `BundledProjectsTests.swift` - Bundled project validation
- `TierIdentifierTests.swift` - Tier ID normalization

All tests use the Swift Testing framework (`@Test`, `@Suite`, `#expect`) and respect
the strict concurrency flags enabled in `Package.swift`.

## Semantic versioning & migration

- **MAJOR** – breaking changes to data models (e.g., removing a field or
  changing required keys) or observable behaviour in core algorithms.
- **MINOR** – additive helpers, new error cases, schema additions that remain backward-compatible.
- **PATCH** – bug fixes and deterministic output corrections with no API signature changes.

## Notes

- **Observation**: Models designed for use with @Observable/@Bindable in Swift 6 UI layers.
- **Export/Analysis**: String formats mirror the web app's structure for compatibility.

## Related docs

- Project overview & build guardrails: [Root README](../README.md)
- tvOS-first design tokens & Liquid Glass guidance: [Design system README](../Tiercade/Design/README.md)
