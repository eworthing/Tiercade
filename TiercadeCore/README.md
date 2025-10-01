# TiercadeCore

Core domain models and logic for the Tiercade native apps. This Swift Package is platform-agnostic and intended to be used by iOS, iPadOS, macOS, and tvOS apps.

## Contents
- **Models**: Item, Items (type alias for [String: [Item]]), TierConfig, History
- **Logic**: TierLogic (move/reorder), HistoryLogic, HeadToHeadLogic, RandomUtils
- **Formatters**: ExportFormatter, AnalysisFormatter
- **Data**: ModelResolver for loading and resolving JSON resources (items, groups, projects)

## Requirements
- **Swift 6.0** toolchain with strict concurrency checking
- **Platforms**: iOS 17+ / macOS 14+ / tvOS 17+
- **Language Mode**: Swift 6 with complete concurrency checking enabled

> Note: The core package maintains broader platform compatibility (iOS 17+) while the main Tiercade app targets OS 26.0+ for latest platform features.

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

## Tests
From the `TiercadeCore` directory:

```sh
swift test
```

All tests use Swift Testing framework (`@Test`, `@Suite`, `#expect`) instead of legacy XCTest.

## Notes
- **Swift 6 Concurrency**: All types conform to Sendable where appropriate for thread-safe usage
- **Observation**: Models designed for use with @Observable in Swift 6
- **Season field**: Decoding is tolerant of string or number (parity with TypeScript implementation)
- **Export/Analysis**: String formats mirror the web app's structure for compatibility
- **RandomUtils**: Implements Lehmer LCG for seeded reproducibility in randomization features
