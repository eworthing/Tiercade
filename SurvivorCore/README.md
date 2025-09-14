# SurvivorCore

Core domain models and logic for the Survivor Tier List native apps. This Swift Package is platform-agnostic and intended to be used by iOS, iPadOS, macOS, and tvOS apps.

## Contents
- Models: Contestant, TierConfig, Tiers, History
- Logic: TierLogic (move/reorder), HistoryLogic, RandomUtils
- Formatters: ExportFormatter, AnalysisFormatter
- Data: DataLoader for decoding JSON resources (contestants, groups)

## Requirements
- Swift 6 toolchain
- Platforms: iOS 17 / macOS 14 / tvOS 17+

## Using in Xcode
1. In your app project, go to File > Add Packages…
2. Choose Add Local, select the `SurvivorCore` folder.
3. Add the library to your app target.

## Quick sample
```swift
import SurvivorCore

let loader = DataLoader()
let contestants = try loader.decodeContestants(from: Data(/* … */))
let groups = try loader.decodeGroups(from: Data(/* … */))
precondition(loader.validate(groups: groups, contestants: contestants))

let tiers: Tiers = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": [Contestant(id: "x", name: "X")]]
let moved = TierLogic.moveContestant(tiers, contestantId: "x", targetTierName: "S")
```

## Tests
From the `SurvivorCore` directory:

```sh
swift test
```

## Notes
- Season field decoding is tolerant of string or number (parity with TS).
- Export/Analysis string formats mirror the web app’s structure.
- RandomUtils implements a Lehmer LCG for seeded reproducibility.
