# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Tiercade is a SwiftUI tier list management app targeting tvOS 26+/iOS 26+ with Swift 6 strict concurrency. Primary platform is tvOS with remote-first UX patterns.

## Essential Commands

### Build & Run (VS Code Task - PREFERRED)

Primary workflow: VS Code task "Build, Install & Launch tvOS" (Cmd+Shift+B)

This runs `./build_install_launch.sh` which:

- Always performs a clean build (forces fresh compilation every time)
- Shows clear progress: 🧹 Cleaning → 🔨 Building → 📦 Installing → 🚀 Launching
- Displays actual build timestamp for verification
- Automatically boots simulator, uninstalls old version, installs fresh build, and launches
- Build location: `~/Library/Developer/Xcode/DerivedData/` (NOT `./build/`)

**Manual Commands (if needed):**

```bash
# Use the script directly
./build_install_launch.sh

# Or direct xcodebuild (builds to DerivedData, not ./build/)
xcodebuild clean -project Tiercade.xcodeproj -scheme Tiercade -configuration Debug
xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' \
  build
```

**IMPORTANT:** Xcode builds to `~/Library/Developer/Xcode/DerivedData/`, NOT `./build/`. Always use the VS Code task to ensure you're installing the correct, freshly-built version.

### Testing

There are currently no active test targets. We intentionally removed legacy tests to start fresh. When tests are reintroduced, prefer Swift Testing and keep tvOS UI automation minimal and accessibility-driven.

### Asset Management

Bundled artwork lives in `Tiercade/Assets.xcassets`. Update images manually and keep identifiers in sync with `AppState+BundledProjects`.

## Architecture

### State Management Pattern

Central `@MainActor @Observable` class in `Tiercade/State/AppState.swift` with feature extensions:

**Critical pattern**: Never mutate state directly. Always route through AppState methods that call TiercadeCore logic:

```swift
// ❌ Wrong - direct mutation
app.tiers["S"]?.append(item)

// ✅ Correct - via AppState extension method
func moveItem(_ id: String, to tier: String) {
    let snapshot = captureTierSnapshot()
    tiers = TierLogic.moveItem(tiers, itemId: id, targetTierName: tier)
    finalizeChange(action: "Move Item", undoSnapshot: snapshot)
}
```

### TiercadeCore Package (Platform-Agnostic)

Swift package at `TiercadeCore/` (iOS 17+/macOS 14+/tvOS 17+) containing:

**Never recreate TL* aliases** — import from TiercadeCore directly.

### View Architecture

Views in `Tiercade/Views/` organized by responsibility:

### Data Flow

```text
User Interaction → SwiftUI View → AppState Method →
TiercadeCore Logic → State Update → UI Auto-Refresh
```

## Swift 6 / OS 26 Requirements

**Strict concurrency enabled** - configuration differs by target type:

**TiercadeCore Package** (library - nonisolated by default):

```swift
// Package.swift
targets: [
    .target(
        name: "TiercadeCore",
        swiftSettings: [
            .enableUpcomingFeature("StrictConcurrency")
            // No default MainActor isolation for maximum library flexibility
        ]
    )
]
```

**Tiercade App** (UI-focused - MainActor by default):

```text
// Xcode project.pbxproj
OTHER_SWIFT_FLAGS = "$(inherited) -enable-upcoming-feature StrictConcurrency -default-isolation MainActor"
```

**Modernization mandates**:

- Target iOS/iPadOS/tvOS/macOS 26 with Swift 6 strict concurrency
- Replace `ObservableObject`/`@Published` with `@Observable` + `@MainActor`
- Prefer SwiftUI navigation APIs such as `NavigationStack`/`NavigationSplitView`
- Adopt structured concurrency primitives (`async`/`await`, `AsyncSequence`, `TaskGroup`)
- Migrate from Combine and callback-based code to async/await pipelines
- Start new persistence work with SwiftData and backfill migrations incrementally
- Author new tests using Swift Testing (`@Test`, `#expect`)
- Enforce cyclomatic complexity limits: warning at 8, error at 12

## tvOS-Specific Patterns

### Focus Management

- Group overlays in `Views/Overlays/` and wrap each with `.focusSection()`
- Use `.allowsHitTesting(!overlayActive)` to keep background interactivity instead of `.disabled()`
- Default to `.focusable(interactions: .activate)` and opt into extras only when required
- Assign accessibility identifiers to actionable leaf views using `{Component}_{Action}`

### Exit Command Pattern

tvOS Menu button dismisses modals, not app:

```swift
#if os(tvOS)
.onExitCommand { app.dismissCurrentOverlay() }
#endif
```

### Design Tokens

Use `Tiercade/Design/` helpers exclusively — no hardcoded values:

- Colors: `Palette.primary`, `Palette.tierS`, etc.
- Typography: `TypeScale.h1`, `TypeScale.body`, etc.
- Spacing: `Metrics.padding`, `Metrics.cardPadding`, `TVMetrics.topBarHeight`
- Effects: `glassEffect`, `GlassEffectContainer`, `.buttonStyle(.glass)`

### UI Testing Constraints

tvOS UI tests excel at **accessibility verification** but struggle with **complex navigation**:

- ✅ Existence checks (`app.buttons["ID"].exists`), element counts, label verification
- ⚠️ Avoid long Siri Remote navigation paths (>12 s) to dodge timeouts
- ♻️ Pass `-uiTest` at launch to toggle test-only hooks when needed

## Debugging & Artifacts

### Build Artifacts

The VS Code build task writes simulator logs to the integrated terminal. Debug logs are also appended to `/tmp/tiercade_debug.log` via `AppState.appendDebugFile()` when enabled.

### Common Issues

1. **"No such module 'TiercadeCore'"** - SourceKit false positive. Trust `xcodebuild` output
2. **Build fails** - Check TiercadeCore added as local package dependency
3. **UI test timeouts** - Reduce navigation, use direct element access
4. **Focus loss** - Verify `.focusSection()` boundaries, check accessibility ID placement
5. **tvOS 26 TLS** - Requires TLS 1.2+ for network requests

### Manual Verification

After every build:

- Boot tvOS 26 Apple TV 4K simulator
- Keep open for visual review (focus halos, Liquid Glass chrome)

Conventional Commits with scope:

```text
feat(tvOS): implement quick move overlay
fix(persistence): resolve theme save race condition
refactor(core): extract history logic to TiercadeCore
test(ui): add QuickSmokeTests for toolbar
docs(readme): update tvOS testing strategy
```

## Apple Documentation Requirement

When working with Apple platforms (iOS, macOS, tvOS, visionOS) or APIs (SwiftUI, UIKit, Focus, HIG), **consult authoritative Apple documentation via apple-docs MCP tools before other sources**.
