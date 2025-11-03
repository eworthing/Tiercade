%23 Architecture Comparison: Current Implementation vs Alternatives

Date: 2025-11-03

## Context

This document evaluates Tiercade’s current tvOS‑first, SwiftUI‑based implementation against three alternative approaches. It analyzes performance, maintainability, and scalability tradeoffs and concludes with a recommendation, grounded in current Apple documentation.

## Current Implementation Snapshot

- SwiftUI UI with modern navigation: `NavigationStack` and `NavigationSplitView`.
- Observation framework `@Observable` for state (not `ObservableObject`).
- Swift 6 strict concurrency enabled (`-strict-concurrency=complete`).
- SwiftData for persistence on new features.
- Native macOS target (no Mac Catalyst), tvOS‑first UX.

References:
- Observation: https://developer.apple.com/documentation/observation/
- Migrate to `@Observable`: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro/
- Adopting Swift 6 strict concurrency: https://developer.apple.com/documentation/swift/adoptingswift6/
- SwiftData: https://developer.apple.com/documentation/swiftdata/
- NavigationStack: https://developer.apple.com/documentation/swiftui/navigationstack/
- NavigationSplitView: https://developer.apple.com/documentation/swiftui/navigationsplitview/

## Approach 1 — Legacy SwiftUI Stack (ObservableObject + Combine + Core Data + Mac Catalyst)

Performance
- `ObservableObject` broadcasts via `objectWillChange`, often causing broader view invalidation than Observation’s property‑scoped tracking.
- Combine pipelines introduce allocation/backpressure overhead; `async/await` typically yields simpler, lower‑latency paths.
- Core Data is optimized but relies on fetched results controllers and merge policies that add indirection compared to SwiftData’s model integration.

Maintainability
- More boilerplate (publishers, cancellables, lifecycle), higher risk of leaks or missed cancellations.
- Catalyst reduces native macOS gaps but introduces UIKit‑on‑macOS quirks and API mismatches.
- Migration debt grows over time; Apple guidance favors Observation over `ObservableObject`.

Scalability
- Core Data scales well but cross‑module setups, merge strategies, and controller wiring increase complexity.
- Catalyst expands the test matrix with platform conditionals and UI parity challenges.

When to prefer
- You must support significantly older OS versions today and accept carrying migration debt until later.

Docs
- Combine: https://developer.apple.com/documentation/combine/
- Core Data: https://developer.apple.com/documentation/coredata/
- Catalyst detection (`isMacCatalystApp`): https://developer.apple.com/documentation/foundation/processinfo/ismaccatalystapp/

## Approach 2 — UIKit/AppKit‑First (platform‑native UI, embed SwiftUI selectively)

Performance
- Maximum control over rendering and tvOS focus behavior; can be optimal for highly bespoke interactions.
- Avoids SwiftUI diffing costs, but loses SwiftUI’s layout/animation efficiencies and requires manual tuning.

Maintainability
- Two primary UI stacks (UIKit for iOS/tvOS, AppKit for macOS) increase duplication and surface area.
- You rebuild many patterns that SwiftUI + Observation provide “for free”, plus bridging concurrency to event‑driven code.

Scalability
- Works for larger teams specializing per‑platform, but cross‑platform parity slows and costs more.
- Hosting SwiftUI inside UIKit/AppKit adds navigation and state sync edges to maintain.

When to prefer
- Exceptional UI or performance requirements that SwiftUI can’t meet and a team ready to sustain parallel UI stacks.

Docs
- tvOS Focus overview (UIKit): https://developer.apple.com/documentation/uikit/about-focus-interactions-for-apple-tv/
- Debugging focus: https://developer.apple.com/documentation/uikit/debugging-focus-issues-in-your-app/

## Approach 3 — Compatibility‑First SwiftUI (broader OS support, reduced strictness, Core Data)

Performance
- Avoids some latest APIs for reach; if Observation/SwiftData require backports or fallbacks, you lose some efficiency benefits.
- Relaxing strict concurrency forfeits compile‑time data race checks without improving runtime cost.

Maintainability
- Fewer breaking adoptions now, but more `#available` gates and compatibility shims, increasing complexity.
- Core Data + SwiftUI works, but carries more boilerplate versus SwiftData’s declarative models.

Scalability
- Wider OS matrix increases testing time and conditional code paths.
- Delays adoption of platform‑specific UX improvements (tvOS/macOS niceties) or forces partial re‑implementations.

When to prefer
- You must support older OS baselines immediately and plan a staged migration to Observation/SwiftData/strict concurrency later.

Docs
- Core Data: https://developer.apple.com/documentation/coredata/
- Material fallback (e.g., `ultraThinMaterial`): https://developer.apple.com/documentation/swiftui/shapestyle/ultrathinmaterial/

## Recommendation

Stay with the current architecture (SwiftUI + Observation + Swift 6 strict concurrency + SwiftData + native macOS) if you can maintain an OS 26 baseline.

Why
- Observation offers fine‑grained, property‑scoped updates with less boilerplate than `ObservableObject`.
- Swift 6 strict concurrency surfaces data races at compile time, improving reliability as the codebase grows.
- SwiftData integrates naturally with SwiftUI and modern navigation, reducing persistence ceremony.
- Native macOS delivers better desktop fidelity and avoids Catalyst edge cases.

When to choose an alternative
- Approach 3: Only if broader OS support is a hard requirement now; define a clear migration plan to today’s stack.
- Approach 2: Only for exceptional UI/perf needs beyond SwiftUI’s envelope and with capacity to maintain dual UI stacks.

## Reference Index (Apple Docs)

- Observation: https://developer.apple.com/documentation/observation/
- Migrate to `@Observable`: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro/
- Adopting Swift 6 strict concurrency: https://developer.apple.com/documentation/swift/adoptingswift6/
- SwiftData: https://developer.apple.com/documentation/swiftdata/
- Core Data: https://developer.apple.com/documentation/coredata/
- Combine: https://developer.apple.com/documentation/combine/
- NavigationStack: https://developer.apple.com/documentation/swiftui/navigationstack/
- NavigationSplitView: https://developer.apple.com/documentation/swiftui/navigationsplitview/
- UIKit tvOS Focus: https://developer.apple.com/documentation/uikit/about-focus-interactions-for-apple-tv/
- Material fallback (`ultraThinMaterial`): https://developer.apple.com/documentation/swiftui/shapestyle/ultrathinmaterial/

