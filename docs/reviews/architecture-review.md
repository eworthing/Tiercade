# Tiercade Architecture Review

## Overview
- Scope: Evaluated Tiercade app (tvOS-first SwiftUI target plus shared iOS/macOS builds) and TiercadeCore package against SOLID, design-pattern, and architectural best practices.
- Method: Surveyed AppState modules, overlay views, Apple Intelligence prototypes, TiercadeCore logic/tests, and shared utilities.

## Findings
### Strengths
- **Domain isolation:** Tier logic, head-to-head heuristics, and randomization utilities live in the `TiercadeCore` SwiftPM package (e.g., `TiercadeCore/Sources/TiercadeCore/Logic/TierLogic.swift`), keeping models and algorithms platform-agnostic and testable.
- **Observation-first UI:** The UI layer uses Swift 6 Observation (`@Observable`, `@Bindable`) in line with [Apple guidance](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro/). Single source of truth is `@MainActor @Observable AppState` injected into views via `.environment(appState)`, minimizing state duplication.
- **tvOS focus compliance:** Overlays such as `QuickMoveOverlay` encapsulate focus coordination with `focusScope`, `defaultFocus`, and `onMoveCommand` while keeping background content interactive, matching tvOS design guidance.
- **Testing culture:** TiercadeCore uses Swift Testing (`swift test`) with granular test targets covering model decoding, head-to-head logic, sorting, and randomization.

### Gaps
- **God object state:** `AppState` (≈200+ properties plus wide extension surface) mixes responsibilities for AI generation, persistence, tier manipulation, overlays, telemetry, and analytics. This violates SRP/LSP and makes the module brittle for extension.
- **Coupled feature flows:** Feature logic (Quick Move, Tier Randomization, Wizard flows, Apple Intelligence retries) resides in `AppState+*.swift`. Views reach directly into `app` mutations, so there is no interface segregation between UI intent and business rules.
- **Weak dependency inversion:** Concrete services (e.g., `FMClient` in `AppleIntelligence+UniqueListGeneration.swift`) are created inside state objects. There are no abstractions for swapping providers or mocking in tests, tying UI state to FoundationModels and SwiftData storage.
- **State leakage into views:** Views bind to the full `AppState` (`@Bindable var app: AppState`), exposing global mutable state to every overlay and component. That hampers reuse and makes unit testing individual surfaces difficult.
- **Telemetry & instrumentation embedded in state:** Acceptance-test boot logging and AI telemetry sit inside AppState methods, polluting production pathways and increasing cognitive load when extending features.

## Recommendations
1. **Decompose AppState into feature aggregates.** Extract `TierListState`, `ThemeState`, `HeadToHeadState`, `AIPrototypeState`, etc., each marked `@Observable`. Keep a lightweight root `AppState` that composes these modules and forwards shared helpers (undo, toast, progress). This restores Single Responsibility and makes each feature independently testable.
2. **Introduce feature services with reducer-style APIs.** Example: build a `QuickMoveFeature` that exposes derived view state (focus targets, tier summaries) and intent methods (`move(to:)`, `toggleSelection()`). Inject this feature into `QuickMoveOverlay` instead of binding to the entire app. Replicate for Head-to-Head and Wizard flows to reduce coupling.
3. **Adopt protocol-driven dependency inversion.** Define interfaces such as `UniqueListGenerating`, `TierPersistenceStore`, `ThemeCatalogProviding`. Implement production adapters (FoundationModels, SwiftData) and inject via initializer parameters or factories (see `AppState+Factory`). This enables mocks/fakes in Swift Testing and keeps experimental Apple Intelligence paths gated.
4. **Promote domain mutations into TiercadeCore.** Move deteministic algorithms (randomization, tier locking, analytics tallies) into the package so UI state primarily coordinates data flow. Return value objects to be applied by state modules, enabling reuse across platforms.
5. **Create an intent/action pipeline.** Introduce a reducer or command dispatcher (e.g., enum `AppAction`) so SwiftUI views dispatch actions rather than mutating state directly. Middleware can handle telemetry, undo history, and analytics consistently while keeping core reducers small.
6. **Separate telemetry and testing hooks.** Wrap acceptance test boot logging, AI telemetry, and debug consoles in opt-in middleware or feature-flagged services. Keep production state lean and reduce risk of test-only code paths leaking into release builds.
7. **Expand targeted test suites.** Once services are modular, add Swift Testing cases around Quick Move focus decisions, batch moves, Apple Intelligence retry heuristics, and persistence stores to prevent regressions during future refactors.

## Suggested Next Steps
1. Prototype a `QuickMoveFeature` (state + service) and migrate `QuickMoveOverlay` to consume it, validating focus defaults and app interaction remain intact.
2. Define protocols/adapters for the AI generator and persistence layers; swap `FMClient` creation to use dependency-injected factories with simple fakes in tests.
3. Plan a phased split of `AppState` into feature aggregates, starting with the heaviest modules (Apple Intelligence prototype, Head-to-Head). Update reducers/tests incrementally after each extraction.
