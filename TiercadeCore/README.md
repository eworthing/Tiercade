# TiercadeCore

Core domain models and logic for the Tiercade native apps. This Swift Package is platform-agnostic and intended to be used by iOS, iPadOS, macOS, and tvOS apps.

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

> Note: The core package now shares the Tiercade app's OS 26.0+ baseline so we can rely on Swift 6 APIs, Liquid Glass effects, and strict concurrency across every module.

## Thread-safety & Sendable guarantees

TiercadeCore is UI-free, pure Swift, and is audited with Swift 6 strict concurrency (`.enableUpcomingFeature("StrictConcurrency")` + `-strict-concurrency=complete`). Public value types (`Item`, `TierConfig`, etc.) conform to `Sendable`. The single escape hatch is the `RandomUtils.Generator` type, which is documented as **not** thread-safe—callers must confine it to a single task or wrap it in an actor if shared.

## Using in Xcode
1. In your app project, go to File > Add Packages…
2. Choose Add Local, select the `TiercadeCore` folder
3. Add the library to your app target

## Quick sample
```swift
import TiercadeCore

let loader = ModelResolver()
let project = try loader.loadProject(from: Data(/* … */))
let items = project.items
let groups = project.groups

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

let resolver = ModelResolver()
let project = try resolver.loadProject(from: bundledData)

var tiers = project.initialTiers()
// Happy path: move succeeds when id + tier exist.
tiers = TierLogic.moveItem(tiers, itemId: "baba", targetTierName: "A")

// Failure mode: returns unchanged set when id missing.
let unchanged = TierLogic.moveItem(tiers, itemId: "missing", targetTierName: "S")
assert(unchanged == tiers)
```

- `TierLogic.moveItem` and `TierLogic.moveItems` never throw; they return the original dictionary if the id/tier combination is invalid.
- `HeadToHeadLogic.initialComparisonQueueWarmStart` throws `HeadToHeadError.notEnoughItems` when fewer than two items are supplied—bubble that to the UI to show a toast.

## Deterministic utilities
- `RandomUtils` uses a Lehmer LCG; providing the same seed yields the same shuffle across app and tests.
- Seeding contract: `RandomUtils.Generator(seed: UInt64)` normalises older 32-bit values, so tests can use fixture seeds (`12345`) safely.
- All random helpers are pure functions over the generator; no global RNG is touched.

## Decoding contracts
- `ModelResolver` accepts either string or numeric `season` values; it stores both the raw string and optional numeric conversion.
- Unknown keys are preserved via `attributes` dictionaries rather than dropped, matching the TypeScript client.
- Required fields: `Item.id`, tier identifiers, and schema version. Missing required fields throw `ModelResolver.Error.invalidResource`.

## Tests
From the `TiercadeCore` directory:

```sh
swift test
```

All tests use Swift Testing framework (`@Test`, `@Suite`, `#expect`) instead of legacy XCTest.
- Place new suites under `Tests/TiercadeCoreTests`.
- CI runs `swift test` with the same strict concurrency flags, so avoid `@MainActor` in tests unless needed.

## Semantic versioning & migration
- **MAJOR** – breaking changes to data models (e.g., removing a field or changing required keys) or observable behaviour in core algorithms.
- **MINOR** – additive helpers, new error cases, schema additions that remain backward-compatible.
- **PATCH** – bug fixes and deterministic output corrections with no API signature changes.

## Notes
- **Observation**: Models designed for use with @Observable/@Bindable in Swift 6 UI layers.
- **Export/Analysis**: String formats mirror the web app's structure for compatibility.

## Related docs
- Project overview & build guardrails: [Root README](../README.md)
- tvOS-first design tokens & Liquid Glass guidance: [Design system README](../Tiercade/Design/README.md)
