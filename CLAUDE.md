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

```bash
# Fetch bundled images from TMDb (requires API key)
export TMDB_API_KEY='your-key'
./tools/fetch_bundled_images.sh
```

## Architecture

### State Management Pattern

Central `@MainActor @Observable` class in `Tiercade/State/AppState.swift` with feature extensions:
- `AppState+Persistence.swift` - Auto-save to UserDefaults
- `AppState+Export.swift` - Multi-format export (.text/.json/.markdown/.csv/.png/.pdf)
- `AppState+Import.swift` - JSON/CSV import with `ModelResolver`
- `AppState+Analysis.swift` - Statistical analysis and balance scoring
- `AppState+HeadToHead.swift` - Binary comparison voting system
- `AppState+Selection.swift` - Multi-select batch operations
- `AppState+Theme.swift` - Theme switching and customization
- `AppState+ThemeCreation.swift` - Custom theme builder
- `AppState+TierListSwitcher.swift` - Project switching
- `AppState+BundledProjects.swift` - Sample tier lists
- `AppState+Items.swift` - Item CRUD operations
- `AppState+Toast.swift`, `+Progress.swift`, `+Search.swift`, `+QuickActions.swift`

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
- **Models**: `Item`, `Items` (typealias for `[String: [Item]]`), `TierConfig`
- **Logic**: `TierLogic`, `HeadToHeadLogic`, `QuickRankLogic`, `RandomUtils`
- **Utilities**: `ModelResolver`, `Formatters`, `DataLoader`

**Never recreate TL* aliases** — import from TiercadeCore directly.

### View Architecture

Views in `Tiercade/Views/` organized by responsibility:
- `Main/MainAppView.swift` - Top-level composition (toolbar, overlays, platform routing)
- `Main/ContentView.swift` - Tier grid and row rendering
- `Main/ContentView+TierRow.swift`, `+TierGrid.swift`, `+Analysis.swift`, `+Sidebar.swift` - Modular extensions
- `Overlays/` - Modal surfaces (QuickMove, ItemMenu, ThemePicker, ThemeCreator, QR)
- `Toolbar/` - Top bar and export sheets
- `Components/` - Reusable parts (Detail, Settings, MediaGallery, FocusTooltip)

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
- State: `@Observable` + `@Bindable` + `@MainActor` (never `ObservableObject`/`@Published`)
- UI: SwiftUI only. `NavigationStack`/`NavigationSplitView` (no `NavigationView`)
- Async: Structured concurrency (`async`/`await`, `AsyncSequence`, `TaskGroup`). Phase out Combine
- Testing: Swift Testing (`@Test`, `#expect`) for new tests. Migrate XCTest incrementally
- Persistence: SwiftData (`@Model`, `@Query`) for new features. Core Data migrated gradually
- Dependencies: SwiftPM only. Use traits: `traits: [.featureFlag("feature-name")]`
- Complexity: SwiftLint enforces `cyclomatic_complexity` warning at 8, error at 12

## tvOS-Specific Patterns

### Focus Management

- **Overlays** use `.focusSection()` + `.focusable()` to contain focus
- **Modal blocking**: Set `.allowsHitTesting(!modalActive)` on background (never `.disabled()` — breaks accessibility)
- **Accessibility IDs** required for UI tests. Convention: `{Component}_{Action}` (e.g., `Toolbar_H2H`, `QuickMove_Overlay`)
- **tvOS 26 interactions**: Use `.focusable(interactions: .activate)` for action-only surfaces
- **Critical bug**: NEVER add `.accessibilityIdentifier()` to parent containers with `.accessibilityElement(children: .contain)` — this overrides child IDs. Apply to leaf elements only

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
- Spacing: `Metrics.padding`, `TVMetrics.topBarHeight`, etc.
- Effects: Liquid Glass via `glassEffect(_:in:)`, `GlassEffectContainer`, `buttonStyle(.glass)` for tvOS 26

### UI Testing Constraints

tvOS UI tests excel at **accessibility verification** but struggle with **complex navigation**:
- ✅ Existence checks (`app.buttons["ID"].exists`), element counts, label verification
- ❌ Multi-step XCUIRemote navigation (slow, timeout >12s)
- **Strategy**: UI tests for structure validation, manual testing for workflows

## Debugging & Artifacts

### Build Artifacts

After `./tools/tvOS_build_and_test.sh`, check `/tmp/`:
- `tiercade_ui_before.png`, `tiercade_ui_after.png` - UI test screenshots
- `tiercade_debug.log` - App debug log via `AppState.appendDebugFile()`
- `tiercade_build_and_test.log` - Full build/test output

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
- Test with Siri Remote simulator (or keyboard: arrows/Space/ESC)

## Commit Conventions

Conventional Commits with scope:
```
feat(tvOS): implement quick move overlay
fix(persistence): resolve theme save race condition
refactor(core): extract history logic to TiercadeCore
test(ui): add QuickSmokeTests for toolbar
docs(readme): update tvOS testing strategy
```

## Apple Documentation Requirement

When working with Apple platforms (iOS, macOS, tvOS, visionOS) or APIs (SwiftUI, UIKit, Focus, HIG), **consult authoritative Apple documentation via apple-docs MCP tools before other sources**.
