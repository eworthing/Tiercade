# HeadToHead Overlay Dynamic Scaling Remediation Plan

**Date:** 2025-11-12
**Component:** HeadToHead Overlay (Views/Overlays/HeadToHeadOverlay*.swift)
**Platform:** tvOS 26+ (primary), iOS 26+, iPadOS 26+, macOS 26+
**Issue:** Text and UI elements don't scale properly for tvOS viewing distance and Dynamic Type accessibility

---

## Validation Notes (2025-11-13)

- Verified Dynamic Type guidance by referencing Apple’s “Applying custom fonts to text” article, which also documents the `ScaledMetric` pattern we rely on for sizing ([source](https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text/)).
- Confirmed layout best practices (flexible containers vs. fixed frames) via the SwiftUI “Layout fundamentals” collection ([source](https://developer.apple.com/documentation/swiftui/layout-fundamentals/)).
- Checked current `TypeScale` definitions directly in `Tiercade/Design/DesignTokens.swift`; only `h2`, `h3`, `body`, `label`, and `metadata` tokens exist today.
- Apple’s public typography HIG page requires JavaScript in order to expose the platform-specific point-size table, so we rendered it with Playwright (Chromium) to capture the authoritative values for iOS/iPadOS, macOS, tvOS, visionOS, and watchOS. Those numbers are now cited in the Apple Guidelines section below.
- All references to “violates Dynamic Type guidelines” now target the actual offending cases (absolute `.font(.system(size: ...))` usages). Instances that already use SwiftUI text styles but bypass our design tokens are flagged as AGENTS.md compliance gaps instead.
- Where statements previously claimed guaranteed accessibility conformance (e.g., “WCAG 2.1 Level AA ✅”), they’ve been rephrased as goals because we haven’t run the required audits yet.

---

## Executive Summary

The HeadToHead overlay was recently rebuilt with correct modal presentation patterns but still violates our AGENTS.md design-token requirements and leaves a few controls (notably iconography) locked to absolute typographic sizes. This document provides a complete remediation plan to enable proper scaling across all platforms while maintaining tvOS-first design principles that align with Apple’s Dynamic Type and layout guidance.

**Impact:** Portions of the overlay ignore user text-size preferences (fixed-size SF Symbols, rigid frames), creating legibility issues—especially on tvOS at a 10-foot viewing distance.

**Effort:** ~3.5 hours implementation + testing
**Priority:** HIGH - Affects accessibility compliance and tvOS UX

---

## Table of Contents

1. [Background](#background)
2. [Current State Analysis](#current-state-analysis)
3. [Violations Identified](#violations-identified)
4. [Apple Guidelines Reference](#apple-guidelines-reference)
5. [AGENTS.md Requirements](#agentsmd-requirements)
6. [Detailed Remediation Plan](#detailed-remediation-plan)
7. [Implementation Steps](#implementation-steps)
8. [Testing & Validation](#testing--validation)
9. [Expected Outcomes](#expected-outcomes)

---

## Background

### Context

The HeadToHead overlay provides an interactive ranking interface where users compare items pairwise. It's a modal overlay presenting:

- Progress dial and metrics
- Two candidate cards for comparison
- Pass/skip tile
- Control buttons (Cancel, Commit)
- Completion state

### Recent Changes

**November 12, 2025:** Overlay restructured to follow Apple modal presentation patterns:

- ✅ Uses `.fullScreenCover()` on tvOS
- ✅ Uses `.sheet()` on macOS
- ✅ Proper focus management with `@FocusState`
- ✅ Liquid Glass effects applied correctly

However, typography and sizing were not updated to follow dynamic scaling best practices.

### Files Affected

```text
Tiercade/Design/DesignTokens.swift              # TypeScale definitions
Tiercade/Views/Overlays/HeadToHeadOverlay.swift # Main overlay
Tiercade/Views/Overlays/HeadToHeadOverlay+HelperViews.swift # Cards, tiles, badges
```

---

## Current State Analysis

### Typography Usage Audit

**File: HeadToHeadOverlay.swift**

| Line | Current Code | Evaluation | Notes |
|------|-------------|------------|-------|
| 142 | `.font(TypeScale.h2)` | ✅ Tokenized | Uses platform-aware token from `TypeScale`. |
| 144 | `.font(TypeScale.body)` | ✅ Tokenized | Matches AGENTS guidance. |
| 158 | `.font(.title3.weight(.semibold))` | ⚠️ Token bypass | Still Dynamic Type friendly, but bypasses `TypeScale`. |
| 160 | `.font(.body)` | ⚠️ Token bypass | Same as above. |

**File: HeadToHeadOverlay+HelperViews.swift**

| Line | Current Code | Component | Evaluation |
|------|-------------|-----------|------------|
| 28 | `.font(.system(size: 26, weight: .semibold))` | Progress icon | ❌ Absolute size (ignores Dynamic Type). |
| 30 | `.font(.headline)` | Progress label | ⚠️ Token bypass (still Dynamic Type). |
| 87 | `.font(TypeScale.h3)` | Card title | ✅ Tokenized. |
| 92 | `.font(.headline)` | Card season | ⚠️ Token bypass. |
| 106 | `.font(TypeScale.body)` | Card description | ✅ Tokenized. |
| 121 | `.font(TypeScale.metadata)` | Card metadata | ⚠️ Token semantics mismatch (secondary text should use `footnote`). |
| 157 | `.font(.system(size: 48, weight: .semibold))` | Pass icon | ❌ Absolute size. |
| 159 | `.font(.headline)` | Pass label | ⚠️ Token bypass. |
| 187 | `.font(.system(size: 64, weight: .bold))` | Completion icon | ❌ Absolute size. |
| 190 | `.font(.title2.weight(.semibold))` | Completion title | ⚠️ Token bypass. |
| 192 | `.font(TypeScale.body)` | Completion text | ✅ Tokenized. |
| 217 | `.font(.footnote.weight(.semibold))` | Phase badge | ⚠️ Token bypass. |
| 251 | `.font(.caption)` | Metric label | ⚠️ Token bypass. |
| 255 | `.font(.title2.weight(.semibold))` | Metric value | ⚠️ Token bypass. |
| 258 | `.font(.caption)` | Metric footnote | ⚠️ Token bypass. |

**Summary:**

- Absolute point-size fonts that truly ignore Dynamic Type: **3** (lines 28, 157, 187).
- Direct SwiftUI text styles that work with Dynamic Type but bypass `TypeScale`: **10** occurrences (lines 30, 92, 158, 160, 159, 190, 217, 251, 255, 258).
- Already tokenized with `TypeScale`: **6** occurrences (lines 142, 144, 87, 106, 121, 192).

> **Note:** SwiftUI text styles such as `.headline` or `.title2` *do* scale with Dynamic Type (per Apple’s documentation), but AGENTS.md requires us to expose all typography through `TypeScale` so that tvOS/iOS/macOS share a single source of truth. The plan below treats these as design-token gaps rather than Dynamic Type violations.

### Frame Size Audit

**Fixed dimensions without ScaledMetric:**

| Location | Code | Issue |
|----------|------|-------|
| HeadToHeadOverlay.swift:153 | `.frame(width: 150, height: 150)` | Progress dial size |
| HeadToHeadOverlay.swift:242 | `.frame(minWidth: 220)` | Cancel button |
| HeadToHeadOverlay.swift:260 | `.frame(minWidth: 260)` | Commit button |
| HelperViews.swift:67-72 | `.frame(minWidth: 360, maxWidth: 520, minHeight: 280)` | Candidate cards |
| HelperViews.swift:161 | `.frame(width: 240, height: 240)` | Pass tile |
| HelperViews.swift:195 | `.frame(maxWidth: 520)` | Completion text |

**Impact:** These dimensions don't scale with Dynamic Type settings. Users with larger text preferences will experience:

- Clipped text in fixed-size containers
- Poor visual hierarchy
- Accessibility non-compliance

### Spacing Audit

**Raw numeric literals found:**

```text
HeadToHeadOverlay.swift:
- Line 138: spacing: 16
- Line 139: spacing: Metrics.grid * 1.5  ✅
- Line 140: spacing: 8
- Line 151: spacing: Metrics.grid * 3   ✅
- Line 156: spacing: 12

HelperViews.swift:
- Line 26: spacing: 6
- Line 33: .padding(.horizontal, 12)
- Line 62: spacing: 18
- Line 66: .padding(Metrics.grid * 3)   ✅
- Line 85: spacing: 10
- Line 99: spacing: 12
- Line 118: spacing: 6
- Line 155: spacing: 16
- Line 197: .padding(.vertical, Metrics.grid * 4)   ✅
- Line 221: .padding(.vertical, 6)
```

**Inconsistency:** ~50% use `Metrics.grid`, 50% use raw numbers

---

## Violations Identified

### Violation 1: Hardcoded Font Sizes

**Apple Guideline:** [Applying custom fonts to text](https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text/)

> “SwiftUI’s adaptive text display scales the font automatically using Dynamic Type.”

**Current violations:**

```swift
// ❌ WRONG: Fixed size, no Dynamic Type support
.font(.system(size: 64, weight: .bold))
.font(.system(size: 48, weight: .semibold))
.font(.system(size: 26, weight: .semibold))
```

**Why this is wrong:**

1. Font size is absolute, doesn't scale with user preferences
2. No relationship to semantic text hierarchy
3. Breaks accessibility for users who need larger text
4. tvOS users at 10-foot distance may find text too small because the icon label never scales up

### Violation 2: Direct SwiftUI Font References

**AGENTS.md Requirement:**

> **Design Tokens:**
> **Use `Design/` helpers exclusively** — no hardcoded values
> Typography: `TypeScale.h1`, `TypeScale.body`, etc.

**Current violations (design-token gap):**

```swift
// ⚠️ Token bypass: still Dynamic Type friendly, but skips TypeScale
.font(.headline)
.font(.body)
.font(.title2.weight(.semibold))
.font(.caption)
.font(.footnote.weight(.semibold))
```

**Why this is wrong:**

1. AGENTS.md mandates that typography flow through `TypeScale` to keep tvOS/iOS/macOS aligned.
2. Without tokens, we must touch every direct `.font()` call when adjusting typographic scale.
3. Cross-overlay hierarchy drifts because some controls inherit TypeScale updates while others do not.
4. Design reviews increasingly rely on token searches (`TypeScale.`) to verify compliance; raw text styles are easy to miss.

### Violation 3: Missing ScaledMetric for Layout Dimensions

**Apple Guideline:** [ScaledMetric documentation](https://developer.apple.com/documentation/swiftui/scaledmetric/)

> A dynamic property that scales a numeric value... Use this property wrapper to scale padding, spacing, and layout dimensions.

**Current violations:**

```swift
// ❌ WRONG: Fixed dimensions, no accessibility scaling
.frame(width: 150, height: 150)
.frame(minWidth: 220)
.frame(width: 240, height: 240)
.frame(minWidth: 360, maxWidth: 520, minHeight: 280)
```

**Why this is wrong:**

1. When users increase text size, containers stay fixed → clipping
2. Button hit targets don't grow proportionally
3. Visual balance breaks at different accessibility sizes
4. Risks violating WCAG 2.1 reflow guidance (1.4.10) because content can’t reflow within the available viewport

### Violation 4: Incomplete TypeScale Token Coverage

**Current TypeScale (DesignTokens.swift:103-118):**

```swift
#if os(tvOS)
internal static let h2 = Font.largeTitle.weight(.bold)
internal static let h3 = Font.title.weight(.semibold)
internal static let body = Font.title3
internal static let label = Font.body
internal static let metadata = Font.title3.weight(.semibold)
#endif
```

**Missing tokens:**

- No `h1` for hero/prominent headings
- No `caption` (smallest readable text)
- No `footnote` (secondary metadata)
- No icon sizing guidance

**Impact:** Developers fall back to hardcoded styles when tokens don't exist.

---

## Apple Guidelines Reference

### Dynamic Type Support

**Source:** [Applying custom fonts to text](https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text/)

- SwiftUI already scales built-in text styles automatically (“SwiftUI’s adaptive text display scales the font automatically using Dynamic Type.”).
- When you need custom typography, Apple recommends tying it back to a text style via `relativeTo:` so it participates in Dynamic Type adjustments.
- The same article highlights using `ScaledMetric` to resize non-text affordances (padding, icon sizes, etc.) in lockstep with accessibility settings.

### Layout Responsiveness

**Source:** [Layout fundamentals](https://developer.apple.com/documentation/swiftui/layout-fundamentals/)

- Apple stresses choosing flexible layout containers (stacks, grids, `ViewThatFits`, etc.) so content can adapt to different interface dimensions.
- Fine-grained adjustments (alignment, spacing, padding) should respond to dynamic metrics instead of fixed constants, especially in modal overlays where available width varies dramatically (tvOS vs. macOS windowed).
- These principles reinforce the plan to pair flexible stacks with `@ScaledMetric` so the overlay remains legible from 10-foot (tvOS) and arm’s-length (iOS/macOS) contexts without introducing per-platform forks.

### Platform Default & Minimum Text Sizes

**Source:** Apple Typography HIG (captured via Playwright-rendered page on 2025-11-13).

| Platform | Default size | Minimum size |
|----------|--------------|--------------|
| iOS / iPadOS | 17 pt | 11 pt |
| macOS | 13 pt | 10 pt |
| tvOS | 29 pt | 23 pt |
| visionOS | 17 pt | 12 pt |
| watchOS | 16 pt | 12 pt |

Apple’s guidance: “Use font sizes that most people can read easily. Follow the recommended default and minimum text sizes for each platform—for both custom and system fonts—to ensure your text is legible on all devices.” Rendering the page with Playwright is necessary because the static HTML returned to non-JS clients omits the table entirely.

### SF Symbol Scaling

**Source:** [Configuring and displaying symbol images in your UI](https://developer.apple.com/documentation/uikit/configuring-and-displaying-symbol-images-in-your-ui/)

- Apple explicitly recommends applying a text style (or semantic image scale) to SF Symbols so “symbol images … scale to match the current Dynamic Type setting.”
- Using `.font(.system(size:))` with a fixed point size defeats this scaling. The remediation plan therefore swaps numeric icon sizes for semantic `Image.Scale` values (or text-style-driven `.imageScale`) so icons grow/shrink alongside adjacent text.

### ScaledMetric Usage Pattern

**Source:** [Applying custom fonts to text - ScaledMetric section](https://developer.apple.com/documentation/swiftui/applying-custom-fonts-to-text/)

```swift
// ✅ CORRECT: Scales with Dynamic Type
@ScaledMetric(relativeTo: .body) private var padding: CGFloat = 20

Text("Hello")
    .padding(padding)
```

**relativeTo parameter:**

- Ties the scaling behavior to a specific text style
- When user increases `.body` text size, `padding` scales proportionally
- Maintains visual relationships across size categories

---

## AGENTS.md Requirements

### Design Token Policy

**Location:** `AGENTS.md:367-378`

```markdown
### Design Tokens
**Use `Design/` helpers exclusively** — no hardcoded values
- Colors: `Palette.primary`, `Palette.text`, `Palette.brand`
- Typography: `TypeScale.h1`, `TypeScale.body`, etc.
- Spacing: `Metrics.padding`, `Metrics.cardPadding`, `TVMetrics.topBarHeight`
```

### Platform Strategy

**Location:** `AGENTS.md:38`

```markdown
Design tokens live in `Tiercade/Design/` (`Palette`, `TypeScale`, `Metrics`, `TVMetrics`).
Reference these rather than hardcoding colors or spacing, especially for tvOS focus chrome.
```

### Testing Requirements

**Location:** `AGENTS.md:622`

```markdown
| `Tiercade/Design` | Tokens (`Palette`, `TypeScale`, `Metrics`, `TVMetrics`) | Visual inspection; no direct tests |
```

**Implication:** All design token changes require manual visual validation across platforms and accessibility settings.

---

## Detailed Remediation Plan

### Strategy

1. **Expand TypeScale** to cover all text styles used in HeadToHead
2. **Introduce ScaledDimensions** enum for layout values
3. **Replace all hardcoded fonts** with TypeScale tokens
4. **Apply ScaledMetric** to all fixed frame dimensions
5. **Audit and consolidate spacing** to use `Metrics.grid` consistently

### Design Principles

- **tvOS-first:** Base sizes optimized for 10-foot viewing
- **Platform-aware:** iOS/macOS scale down proportionally
- **Semantic naming:** Token names describe purpose, not size
- **Graceful degradation:** If token doesn't exist, fail to compile (not silent fallback)

---

## Implementation Steps

### Phase 1: Expand TypeScale

**File:** `Tiercade/Design/DesignTokens.swift`

**Current state (lines 103-118):**

```swift
internal enum TypeScale {
    #if os(tvOS)
    internal static let h2 = Font.largeTitle.weight(.bold)
    internal static let h3 = Font.title.weight(.semibold)
    internal static let body = Font.title3
    internal static let label = Font.body
    internal static let metadata = Font.title3.weight(.semibold)
    #else
    internal static let h2 = Font.title.weight(.semibold)
    internal static let h3 = Font.title2.weight(.semibold)
    internal static let body = Font.body
    internal static let label = Font.caption
    internal static let metadata = Font.subheadline.weight(.semibold)
    #endif
}
```

**Replacement:**

```swift
internal enum TypeScale {
    // MARK: - Semantic Text Styles (Dynamic Type compatible)

    #if os(tvOS)
    // tvOS: Optimized for 10-foot viewing distance

    /// Hero headings (96pt base) - Major section titles, prominent announcements
    internal static let h1 = Font.system(size: 96, design: .default).weight(.heavy)

    /// Large headings (76pt base) - Overlay titles, page headers
    internal static let h2 = Font.largeTitle.weight(.bold)

    /// Section headings (57pt base) - Card titles, subsection headers
    internal static let h3 = Font.title.weight(.semibold)

    /// Primary body text (38pt base) - Main content, descriptions
    internal static let body = Font.title3

    /// Secondary body text (31pt base) - Supporting content
    internal static let bodySmall = Font.headline

    /// Button labels (29pt base) - Action labels, tabs
    internal static let label = Font.body

    /// Small labels (25pt base) - Status text, badges, tertiary actions
    internal static let caption = Font.callout.weight(.medium)

    /// Fine print (23pt base) - Metadata, timestamps, secondary info
    internal static let footnote = Font.body.weight(.regular)

    /// Emphasized metadata (38pt base) - Stats, highlighted metrics
    internal static let metadata = Font.title3.weight(.semibold)

    // MARK: - SF Symbol Scaling

    internal enum IconScale {
        /// Inline icons aligned with body text. tvOS needs a larger baseline, so default to `.medium`.
        internal static let small: Image.Scale = .medium

        /// Primary action icons (buttons, tiles) – rendered at `.large` on tvOS for 10-foot legibility.
        internal static let medium: Image.Scale = .large

        /// Hero icons (completion states) – tvOS also uses `.large`; combine with `fontWeight` for emphasis.
        internal static let large: Image.Scale = .large
    }

    #else
    // iOS/iPadOS/macOS: Arm's length viewing distance

    /// Hero headings (48pt base) - Major section titles
    internal static let h1 = Font.system(size: 48, design: .default).weight(.heavy)

    /// Large headings (34pt base) - Overlay titles
    internal static let h2 = Font.title.weight(.semibold)

    /// Section headings (28pt base) - Card titles
    internal static let h3 = Font.title2.weight(.semibold)

    /// Primary body text (17pt base) - Main content
    internal static let body = Font.body

    /// Secondary body text (16pt base) - Supporting content
    internal static let bodySmall = Font.callout

    /// Button labels (12pt base) - Action labels
    internal static let label = Font.caption

    /// Small labels (11pt base) - Status text, badges
    internal static let caption = Font.caption2.weight(.medium)

    /// Fine print (13pt base) - Metadata, timestamps
    internal static let footnote = Font.footnote.weight(.regular)

    /// Emphasized metadata (15pt base) - Stats, metrics
    internal static let metadata = Font.subheadline.weight(.semibold)

    internal enum IconScale {
        internal static let small: Image.Scale = .small
        internal static let medium: Image.Scale = .medium
        internal static let large: Image.Scale = .large
    }

    #endif
}
```

**Rationale for each token:**

| Token | Purpose | HeadToHead Usage |
|-------|---------|------------------|
| `h1` | Hero content | Future: Session start/complete states |
| `h2` | Overlay title | "HeadToHead Arena" heading |
| `h3` | Card titles | Candidate names, completion title |
| `body` | Descriptions | Candidate descriptions, instructions |
| `bodySmall` | Secondary text | Reserved for future use |
| `label` | Button text | Reserved for future use |
| `caption` | Small labels | "Pass for Now", season indicators |
| `footnote` | Fine print | Phase badge, metric footnotes |
| `metadata` | Stats | Metric values (currently misused) |
| `IconScale.large` | Hero icons | Completion crown |
| `IconScale.medium` | Action icons | Pass tile icon |
| `IconScale.small` | Inline icons | Progress dial icon |

**Testing this change:**

```bash
# Build to verify no regressions
./build_install_launch.sh --no-launch

# No other code changes yet, should build successfully
# Existing TypeScale usages still work (h2, h3, body, metadata)
```

---

### Phase 2: Add ScaledDimensions Enum

**File:** `Tiercade/Design/DesignTokens.swift`

**Location:** Add after `Metrics` enum (after line 101)

```swift
// MARK: - Scaled Layout Dimensions

/// Layout dimensions that scale with Dynamic Type
/// Use these constants with @ScaledMetric property wrapper for accessibility-aware sizing
internal enum ScaledDimensions {
    #if os(tvOS)
    // tvOS: Larger dimensions for 10-foot viewing

    // MARK: HeadToHead Overlay Components

    /// Progress dial circular size (diameter)
    internal static let progressDialSize: CGFloat = 150

    /// Candidate card minimum/maximum dimensions
    internal static let candidateCardMinWidth: CGFloat = 360
    internal static let candidateCardMaxWidth: CGFloat = 520
    internal static let candidateCardMinHeight: CGFloat = 280

    /// Pass tile square size (width = height)
    internal static let passTileSize: CGFloat = 240

    /// Button minimum widths for consistent sizing
    internal static let buttonMinWidthSmall: CGFloat = 220   // Cancel, secondary actions
    internal static let buttonMinWidthLarge: CGFloat = 260   // Commit, primary actions

    /// Maximum width for text content blocks (readability constraint)
    internal static let textContentMaxWidth: CGFloat = 520

    #else
    // iOS/iPadOS/macOS: Proportionally smaller for closer viewing

    internal static let progressDialSize: CGFloat = 100
    internal static let candidateCardMinWidth: CGFloat = 280
    internal static let candidateCardMaxWidth: CGFloat = 400
    internal static let candidateCardMinHeight: CGFloat = 220
    internal static let passTileSize: CGFloat = 180
    internal static let buttonMinWidthSmall: CGFloat = 180
    internal static let buttonMinWidthLarge: CGFloat = 200
    internal static let textContentMaxWidth: CGFloat = 420

    #endif
}
```

**Rationale:**

1. **Centralized dimensions** - Single source of truth for all scaled values
2. **Platform-aware** - tvOS values ~1.5x larger than iOS/macOS
3. **Named semantically** - `buttonMinWidthLarge` describes purpose, not pixel count
4. **ScaledMetric ready** - These are base values; `@ScaledMetric` wrapper will scale them further

**Usage pattern:**

```swift
// In a SwiftUI view
@ScaledMetric(relativeTo: .body) private var buttonWidth = ScaledDimensions.buttonMinWidthLarge

// In body
Button("Commit") { }
    .frame(minWidth: buttonWidth)  // Scales with Dynamic Type
```

**Testing this change:**

```bash
# Build to verify enum compiles
./build_install_launch.sh --no-launch

# No usage yet, purely additive
```

---

### Phase 3: Update HeadToHeadOverlay.swift

**File:** `Tiercade/Views/Overlays/HeadToHeadOverlay.swift`

#### Change 3.1: Add ScaledMetric Properties

**Location:** After line 20 (after `private let minOverlayWidth`)

**Add:**

```swift
// MARK: - Scaled Dimensions
@ScaledMetric(relativeTo: .title3) private var progressDialSize = ScaledDimensions.progressDialSize
@ScaledMetric(relativeTo: .body) private var buttonMinWidthSmall = ScaledDimensions.buttonMinWidthSmall
@ScaledMetric(relativeTo: .body) private var buttonMinWidthLarge = ScaledDimensions.buttonMinWidthLarge
```

**Rationale:**

- `progressDialSize` tied to `.title3` because progress label uses TypeScale.body (title3 on tvOS)
- Button widths tied to `.body` for proportional scaling with typical button label text

#### Change 3.2: Update Progress Dial Frame

**Location:** Line 153

**Before:**

```swift
.frame(width: 150, height: 150)
```

**After:**

```swift
.frame(width: progressDialSize, height: progressDialSize)
```

#### Change 3.3: Update Status Text Styles

**Location:** Lines 158, 160

**Before:**

```swift
Text(statusSummary)
    .font(.title3.weight(.semibold))
Text(secondaryStatus)
    .font(.body)
```

**After:**

```swift
Text(statusSummary)
    .font(TypeScale.h3)
Text(secondaryStatus)
    .font(TypeScale.body)
```

**Rationale:**

- `statusSummary` is a prominent heading → `h3`
- `secondaryStatus` is descriptive text → `body`

#### Change 3.4: Update Button Frames

**Location:** Lines 242, 260

**Before:**

```swift
Button(role: .destructive) {
    app.cancelHeadToHead()
} label: {
    Label("Leave Session", systemImage: "xmark.circle")
        .labelStyle(.titleAndIcon)
        .frame(minWidth: 220)
}

Button {
    app.finishHeadToHead()
} label: {
    Label("Commit Rankings", systemImage: "checkmark.seal")
        .labelStyle(.titleAndIcon)
        .frame(minWidth: 260)
}
```

**After:**

```swift
Button(role: .destructive) {
    app.cancelHeadToHead()
} label: {
    Label("Leave Session", systemImage: "xmark.circle")
        .labelStyle(.titleAndIcon)
        .frame(minWidth: buttonMinWidthSmall)
}

Button {
    app.finishHeadToHead()
} label: {
    Label("Commit Rankings", systemImage: "checkmark.seal")
        .labelStyle(.titleAndIcon)
        .frame(minWidth: buttonMinWidthLarge)
}
```

**Testing Phase 3:**

```bash
# Build to verify changes compile
./build_install_launch.sh --no-launch

# Launch tvOS to visually inspect
./build_install_launch.sh tvos

# In Simulator: Settings > Accessibility > Display & Text Size > Larger Text
# Drag slider to test Dynamic Type scaling
```

---

### Phase 4: Update HeadToHeadOverlay+HelperViews.swift

**File:** `Tiercade/Views/Overlays/HeadToHeadOverlay+HelperViews.swift`

#### Change 4.1: HeadToHeadProgressDial

**Location:** Lines 4-50

**Before:**

```swift
internal struct HeadToHeadProgressDial: View {
    internal let progress: Double
    internal let label: String

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    internal var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 14)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Palette.brand, Palette.tierColor("S"), Palette.brand]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 6) {
                Image(systemName: symbolName)
                    .font(.system(size: 26, weight: .semibold))
                Text(label)
                    .font(.headline)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HeadToHead progress")
        .accessibilityValue(label)
    }

    private var symbolName: String {
        switch clampedProgress {
        case 0..<0.25:
            return "gauge.low"
        case 0.25..<0.75:
            return "gauge.medium"
        default:
            return "gauge.high"
        }
    }
}
```

**After:**

```swift
internal struct HeadToHeadProgressDial: View {
    internal let progress: Double
    internal let label: String

    private var clampedProgress: Double { min(max(progress, 0), 1) }

    internal var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 14)

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [Palette.brand, Palette.tierColor("S"), Palette.brand]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: Metrics.grid * 0.75) {
                Image(systemName: symbolName)
                    .imageScale(TypeScale.IconScale.small)
                    .fontWeight(.semibold)
                Text(label)
                    .font(TypeScale.caption)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, Metrics.grid * 1.5)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HeadToHead progress")
        .accessibilityValue(label)
    }

    private var symbolName: String {
        switch clampedProgress {
        case 0..<0.25:
            return "gauge.low"
        case 0.25..<0.75:
            return "gauge.medium"
        default:
            return "gauge.high"
        }
    }
}
```

**Changes:**

- Line 26: `spacing: 6` → `spacing: Metrics.grid * 0.75`
- Line 28: `.font(.system(size: 26...))` → `.imageScale(TypeScale.IconScale.small)`
- Line 30: `.font(.headline)` → `.font(TypeScale.caption)`
- Line 33: `.padding(.horizontal, 12)` → `.padding(.horizontal, Metrics.grid * 1.5)`

#### Change 4.2: HeadToHeadCandidateCard

**Location:** Lines 52-148

**Before (key sections):**

```swift
internal struct HeadToHeadCandidateCard: View {
    // ... properties ...

    internal var body: some View {
        Button(action: action) {
            VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 18) {
                header
                detail
            }
            .padding(Metrics.grid * 3)
            .frame(
                minWidth: 360,
                maxWidth: 520,
                minHeight: 280,
                alignment: alignment == .leading ? .topLeading : .topTrailing
            )
            .background(backgroundShape)
        }
        // ...
    }

    private var header: some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 10) {
            Text(item.name ?? item.id)
                .font(TypeScale.h3)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                .lineLimit(3)
            if let season = item.seasonString, !season.isEmpty {
                Text("Season \(season)")
                    .font(.headline)
                    .foregroundStyle(accentColor)
            }
        }
    }

    private var detail: some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: 12) {
            if !metadataTokens.isEmpty {
                metadataStack
            }

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(TypeScale.body)
                    .foregroundStyle(.primary)
                    .lineLimit(5)
                    .lineSpacing(6)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            }
        }
    }

    private var metadataStack: some View {
        let alignment: HorizontalAlignment = self.alignment == .leading ? .leading : .trailing

        return VStack(alignment: alignment, spacing: 6) {
            ForEach(metadataTokens, id: \.self) { token in
                Text(token)
                    .font(TypeScale.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(self.alignment == .leading ? .leading : .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // ... metadataTokens and backgroundShape ...
}
```

**After:**

```swift
internal struct HeadToHeadCandidateCard: View {
    enum AlignmentHint { case leading, trailing }

    internal let item: Item
    internal let accentColor: Color
    internal let alignment: AlignmentHint
    internal let action: () -> Void

    @ScaledMetric(relativeTo: .title) private var cardMinWidth = ScaledDimensions.candidateCardMinWidth
    @ScaledMetric(relativeTo: .title) private var cardMaxWidth = ScaledDimensions.candidateCardMaxWidth
    @ScaledMetric(relativeTo: .title) private var cardMinHeight = ScaledDimensions.candidateCardMinHeight

    internal var body: some View {
        Button(action: action) {
            VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: Metrics.grid * 2.25) {
                header
                detail
            }
            .padding(Metrics.grid * 3)
            .frame(
                minWidth: cardMinWidth,
                maxWidth: cardMaxWidth,
                minHeight: cardMinHeight,
                alignment: alignment == .leading ? .topLeading : .topTrailing
            )
            .background(backgroundShape)
        }
        #if os(tvOS)
        .buttonStyle(.glass)
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel(item.name ?? item.id)
        .accessibilityHint(item.description ?? "Choose this contender")
    }

    private var header: some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: Metrics.grid * 1.25) {
            Text(item.name ?? item.id)
                .font(TypeScale.h3)
                .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
                .lineLimit(3)
            if let season = item.seasonString, !season.isEmpty {
                Text("Season \(season)")
                    .font(TypeScale.caption)
                    .foregroundStyle(accentColor)
            }
        }
    }

    private var detail: some View {
        VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: Metrics.grid * 1.5) {
            if !metadataTokens.isEmpty {
                metadataStack
            }

            if let description = item.description, !description.isEmpty {
                Text(description)
                    .font(TypeScale.body)
                    .foregroundStyle(.primary)
                    .lineLimit(5)
                    .lineSpacing(Metrics.grid * 0.75)
                    .multilineTextAlignment(alignment == .leading ? .leading : .trailing)
            }
        }
    }

    private var metadataStack: some View {
        let alignment: HorizontalAlignment = self.alignment == .leading ? .leading : .trailing

        return VStack(alignment: alignment, spacing: Metrics.grid * 0.75) {
            ForEach(metadataTokens, id: \.self) { token in
                Text(token)
                    .font(TypeScale.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(self.alignment == .leading ? .leading : .trailing)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var metadataTokens: [String] {
        var tokens: [String] = []
        if let season = item.seasonString, !season.isEmpty {
            tokens.append("Season \(season)")
        }
        if let status = item.status, !status.isEmpty {
            tokens.append(status)
        }
        return tokens
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 30, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(accentColor.opacity(0.4), lineWidth: 1.6)
            )
    }
}
```

**Changes:**

- Added `@ScaledMetric` properties for card dimensions (lines 8-10)
- Line 15: `spacing: 18` → `spacing: Metrics.grid * 2.25`
- Line 20-24: Fixed dimensions → ScaledMetric properties
- Line 35: `spacing: 10` → `spacing: Metrics.grid * 1.25`
- Line 42: `.font(.headline)` → `.font(TypeScale.caption)`
- Line 49: `spacing: 12` → `spacing: Metrics.grid * 1.5`
- Line 57: `lineSpacing(6)` → `lineSpacing(Metrics.grid * 0.75)`
- Line 66: `spacing: 6` → `spacing: Metrics.grid * 0.75`
- Line 69: `.font(TypeScale.metadata)` → `.font(TypeScale.footnote)`

**Rationale for metadata → footnote:**

- Metadata tokens (season, status) are secondary information
- TypeScale.metadata is currently `title3.weight(.semibold)` on tvOS (large, bold)
- TypeScale.footnote is `body.weight(.regular)` (smaller, subtle) - correct semantic choice

#### Change 4.3: HeadToHeadPassTile

**Location:** Lines 150-181

**Before:**

```swift
internal struct HeadToHeadPassTile: View {
    internal let action: () -> Void

    internal var body: some View {
        Button(action: action) {
            VStack(spacing: 16) {
                Image(systemName: "arrow.uturn.left.circle")
                    .font(.system(size: 48, weight: .semibold))
                Text("Pass for Now")
                    .font(.headline)
            }
            .frame(width: 240, height: 240)
            .background(tileShape)
        }
        #if os(tvOS)
        .buttonStyle(.glass)
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel("Pass on this pairing")
        .accessibilityHint("Skip and revisit later")
    }

    private var tileShape: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.26), lineWidth: 1.4)
            )
    }
}
```

**After:**

```swift
internal struct HeadToHeadPassTile: View {
    internal let action: () -> Void

    @ScaledMetric(relativeTo: .title2) private var tileSize = ScaledDimensions.passTileSize

    internal var body: some View {
        Button(action: action) {
            VStack(spacing: Metrics.grid * 2) {
                Image(systemName: "arrow.uturn.left.circle")
                    .imageScale(TypeScale.IconScale.medium)
                    .fontWeight(.semibold)
                Text("Pass for Now")
                    .font(TypeScale.caption)
            }
            .frame(width: tileSize, height: tileSize)
            .background(tileShape)
        }
        #if os(tvOS)
        .buttonStyle(.glass)
        #else
        .buttonStyle(.plain)
        #endif
        .accessibilityLabel("Pass on this pairing")
        .accessibilityHint("Skip and revisit later")
    }

    private var tileShape: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.white.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.26), lineWidth: 1.4)
            )
    }
}
```

**Changes:**

- Added `@ScaledMetric` for tile size (line 4)
- Line 8: `spacing: 16` → `spacing: Metrics.grid * 2`
- Line 10: `.font(.system(size: 48...))` → `.imageScale(TypeScale.IconScale.medium)`
- Line 12: `.font(.headline)` → `.font(TypeScale.caption)`
- Line 14: Fixed dimensions → `tileSize` property

#### Change 4.4: HeadToHeadCompletionPanel

**Location:** Lines 183-209

**Before:**

```swift
internal struct HeadToHeadCompletionPanel: View {
    internal var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 64, weight: .bold))
                .symbolRenderingMode(.hierarchical)
            Text("All comparisons complete")
                .font(.title2.weight(.semibold))
            Text("Choose Commit Rankings to apply your results or leave the session to discard them.")
                .font(TypeScale.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)
        }
        .padding(.vertical, Metrics.grid * 4)
        .padding(.horizontal, Metrics.grid * 5)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1.4)
                )
        )
        .accessibilityIdentifier("HeadToHeadOverlay_Complete")
    }
}
```

**After:**

```swift
internal struct HeadToHeadCompletionPanel: View {
    @ScaledMetric(relativeTo: .body) private var textMaxWidth = ScaledDimensions.textContentMaxWidth

    internal var body: some View {
        VStack(spacing: Metrics.grid * 2) {
            Image(systemName: "crown.fill")
                .imageScale(TypeScale.IconScale.large)
                .fontWeight(.bold)
                .symbolRenderingMode(.hierarchical)
            Text("All comparisons complete")
                .font(TypeScale.h3)
            Text("Choose Commit Rankings to apply your results or leave the session to discard them.")
                .font(TypeScale.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: textMaxWidth)
        }
        .padding(.vertical, Metrics.grid * 4)
        .padding(.horizontal, Metrics.grid * 5)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1.4)
                )
        )
        .accessibilityIdentifier("HeadToHeadOverlay_Complete")
    }
}
```

**Changes:**

- Added `@ScaledMetric` for text width (line 2)
- Line 5: `spacing: 16` → `spacing: Metrics.grid * 2`
- Line 7: `.font(.system(size: 64...))` → `.imageScale(TypeScale.IconScale.large)`
- Line 10: `.font(.title2.weight(.semibold))` → `.font(TypeScale.h3)`
- Line 15: Fixed dimension → `textMaxWidth` property

#### Change 4.5: HeadToHeadPhaseBadge

**Location:** Lines 211-241

**Before:**

```swift
internal struct HeadToHeadPhaseBadge: View {
    internal let phase: HeadToHeadPhase

    internal var body: some View {
        Label {
            Text(phaseLabel)
                .font(.footnote.weight(.semibold))
        } icon: {
            Image(systemName: phaseIcon)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Capsule().fill(Color.white.opacity(0.12)))
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .accessibilityLabel("HeadToHead phase \(phaseLabel)")
    }

    private var phaseLabel: String {
        switch phase {
        case .quick: return "Quick pass"
        case .refinement: return "Refinement"
        }
    }

    private var phaseIcon: String {
        switch phase {
        case .quick: return "bolt.fill"
        case .refinement: return "sparkles"
        }
    }
}
```

**After:**

```swift
internal struct HeadToHeadPhaseBadge: View {
    internal let phase: HeadToHeadPhase

    internal var body: some View {
        Label {
            Text(phaseLabel)
                .font(TypeScale.footnote)
        } icon: {
            Image(systemName: phaseIcon)
        }
        .padding(.vertical, Metrics.grid * 0.75)
        .padding(.horizontal, Metrics.grid * 1.5)
        .background(Capsule().fill(Color.white.opacity(0.12)))
        .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        .accessibilityLabel("HeadToHead phase \(phaseLabel)")
    }

    private var phaseLabel: String {
        switch phase {
        case .quick: return "Quick pass"
        case .refinement: return "Refinement"
        }
    }

    private var phaseIcon: String {
        switch phase {
        case .quick: return "bolt.fill"
        case .refinement: return "sparkles"
        }
    }
}
```

**Changes:**

- Line 7: `.font(.footnote.weight(.semibold))` → `.font(TypeScale.footnote)`
- Line 11: `.padding(.vertical, 6)` → `.padding(.vertical, Metrics.grid * 0.75)`
- Line 12: `.padding(.horizontal, 12)` → `.padding(.horizontal, Metrics.grid * 1.5)`

**Note:** `TypeScale.footnote` already includes `.weight(.regular)` on tvOS. The visual weight comes from the badge background, not font weight.

#### Change 4.6: HeadToHeadMetricTile

**Location:** Lines 243-267

**Before:**

```swift
internal struct HeadToHeadMetricTile: View {
    internal let title: String
    internal let value: String
    internal let footnote: String?

    internal var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption)
                .kerning(1.1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
```

**After:**

```swift
internal struct HeadToHeadMetricTile: View {
    internal let title: String
    internal let value: String
    internal let footnote: String?

    internal var body: some View {
        VStack(alignment: .leading, spacing: Metrics.grid * 0.5) {
            Text(title.uppercased())
                .font(TypeScale.footnote)
                .kerning(1.1)
                .foregroundStyle(.secondary)
            Text(value)
                .font(TypeScale.h3)
            if let footnote {
                Text(footnote)
                    .font(TypeScale.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Metrics.grid)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}
```

**Changes:**

- Line 7: `spacing: 4` → `spacing: Metrics.grid * 0.5`
- Line 9: `.font(.caption)` → `.font(TypeScale.footnote)`
- Line 13: `.font(.title2.weight(.semibold))` → `.font(TypeScale.h3)`
- Line 16: `.font(.caption)` → `.font(TypeScale.footnote)`
- Line 20: `.padding(.vertical, 8)` → `.padding(.vertical, Metrics.grid)`

**Rationale:**

- Metric value should be prominent → `h3` (was title2, semantically similar)
- Title and footnote are small labels → `footnote` (was caption, now consistent)

**Testing Phase 4:**

```bash
# Full build all platforms
./build_install_launch.sh --no-launch

# Expected: All platforms build successfully

# Launch tvOS
./build_install_launch.sh tvos

# Visual validation:
# 1. All text should be readable at 10-foot distance
# 2. Hierarchy should be clear (headings > body > captions)
# 3. Icons should scale proportionally with text
# 4. No clipped text in containers

# Test Dynamic Type:
# tvOS Simulator > Settings > Accessibility > Display & Text Size > Larger Text
# Move slider to max, return to app
# Expected: All text/layout scales up gracefully, no overlap/clipping
```

---

### Phase 5: Audit Remaining Spacing

**Goal:** Replace all raw numeric literals with `Metrics.grid` expressions

**Approach:**

```bash
# Find all remaining numeric spacing
cd /Users/Shared/git/Tiercade
grep -n "spacing: [0-9]" Tiercade/Views/Overlays/HeadToHead*.swift
```

**Expected Phase 4 results:** Most should be fixed. Any remaining instances likely in:

- `HeadToHeadOverlay.swift` lines 138-163 (overview section internal spacing)

**Audit & fix:**

| Line | Current | Replacement | Rationale |
|------|---------|-------------|-----------|
| 138 | `spacing: 16` | `spacing: Metrics.grid * 2` | Standard section spacing |
| 140 | `spacing: 8` | `spacing: Metrics.grid` | Tight internal spacing |
| 156 | `spacing: 12` | `spacing: Metrics.grid * 1.5` | Metric tile internal spacing |

**Apply changes:**

```swift
// HeadToHeadOverlay.swift, line 138-178
private var overviewSection: some View {
    VStack(alignment: .leading, spacing: Metrics.grid * 2) {  // was: 16
        HStack(alignment: .firstTextBaseline, spacing: Metrics.grid * 1.5) {
            VStack(alignment: .leading, spacing: Metrics.grid) {  // was: 8
                Text("HeadToHead Arena")
                    .font(TypeScale.h2)
                Text("Compare contenders, resolve ties, and keep your rankings focused.")
                    .font(TypeScale.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HeadToHeadPhaseBadge(phase: app.headToHead.phase)
        }
        HStack(alignment: .center, spacing: Metrics.grid * 3) {
            HeadToHeadProgressDial(progress: app.headToHead.overallProgress, label: progressLabel)
                .frame(width: progressDialSize, height: progressDialSize)
                .accessibilityIdentifier("HeadToHeadOverlay_Progress")

            VStack(alignment: .leading, spacing: Metrics.grid * 1.5) {  // was: 12
                Text(statusSummary)
                    .font(TypeScale.h3)
                Text(secondaryStatus)
                    .font(TypeScale.body)
                    .foregroundStyle(.secondary)

                HStack(spacing: Metrics.grid * 2.5) {
                    ForEach(metricTiles, id: \.title) { metric in
                        HeadToHeadMetricTile(
                            title: metric.title,
                            value: metric.value,
                            footnote: metric.caption
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("HeadToHeadOverlay_Header")
}
```

**Final grep verification:**

```bash
# Should return 0 results (all spacing uses Metrics.grid)
grep -n "spacing: [0-9]" Tiercade/Views/Overlays/HeadToHead*.swift

# Should return 0 results (all fonts use TypeScale)
grep -n "\.font(\\.system(size: [0-9]" Tiercade/Views/Overlays/HeadToHead*.swift

# Should return results only with TypeScale constants
grep -n "\.font(\\.system(size: TypeScale\." Tiercade/Views/Overlays/HeadToHead*.swift
```

---

## Testing & Validation

### Build Verification

```bash
# Clean build all platforms
./build_install_launch.sh --no-launch

# Expected output:
# ✅ tvOS: BUILD SUCCEEDED
# ✅ iOS: BUILD SUCCEEDED
# ✅ iPadOS: BUILD SUCCEEDED
# ✅ macOS: BUILD SUCCEEDED
```

### Visual Inspection - tvOS

1. **Launch tvOS simulator:**

   ```bash
   ./build_install_launch.sh tvos
   ```

2. **Navigate to HeadToHead:**
   - Focus on any tier list
   - Press Play/Pause → HeadToHead Arena button
   - Overlay should appear

3. **Visual checklist:**
   - [ ] Heading "HeadToHead Arena" is largest, bold, clearly readable
   - [ ] Body text (description) is medium size, comfortable to read
   - [ ] Progress dial icon and label are appropriately sized
   - [ ] Candidate cards have clear hierarchy: name > description > metadata
   - [ ] Pass tile icon and text are balanced
   - [ ] Buttons have consistent sizing
   - [ ] No text clipping or overlap

### Accessibility Testing - tvOS

1. **Enable Larger Text:**
   - tvOS Simulator → I/O menu → Keyboard → Send Keyboard Input
   - Navigate: Settings → Accessibility → Display & Text Size → Larger Text
   - Enable "Larger Accessibility Sizes"
   - Drag slider to 75% (2 notches from max)

2. **Return to app:**
   - Swipe up from bottom to app switcher
   - Return to Tiercade

3. **Visual checklist at 75% scale:**
   - [ ] All text is larger but maintains hierarchy
   - [ ] Progress dial scaled up proportionally
   - [ ] Candidate cards expanded to accommodate larger text
   - [ ] No text clipped in fixed containers
   - [ ] Button hit targets are larger
   - [ ] Layout remains balanced (no excessive whitespace)

4. **Test at 100% scale (maximum):**
   - Repeat navigation to Larger Text settings
   - Move slider to max
   - Return to app

5. **Extreme scale checklist:**
   - [ ] Overlay remains usable (may require scrolling)
   - [ ] Critical info (candidate names, buttons) still visible
   - [ ] No crashes or layout breaks

### Accessibility Testing - iOS

1. **Launch iOS simulator:**

   ```bash
   ./build_install_launch.sh ios
   ```

2. **Enable Dynamic Type:**
   - Settings → Accessibility → Display & Text Size → Larger Text
   - Enable "Larger Accessibility Sizes"
   - Drag to 75%

3. **Visual checklist:**
   - [ ] iOS text styles (smaller than tvOS) scale correctly
   - [ ] Sheet presentation (not fullScreenCover) works properly
   - [ ] Touch targets remain adequate (44pt minimum)

### Cross-Platform Comparison

**Expected platform differences:** *(values derived from the proposed `TypeScale`/`ScaledDimensions` base sizes — they are design targets, not Apple-provided numbers)*

| Element | tvOS | iOS/macOS |
|---------|------|-----------|
| h2 (title) | ~76pt | ~34pt |
| h3 (section) | ~57pt | ~28pt |
| body | ~38pt | ~17pt |
| Progress dial | 150pt | 100pt |
| Candidate card min width | 360pt | 280pt |
| Button min width | 220-260pt | 180-200pt |

**Visual comparison:**

1. Launch tvOS and iOS simulators side-by-side
2. Open HeadToHead on both
3. Confirm proportions are maintained (tvOS ~1.5-2x larger)

### Regression Testing

**Other overlays to spot-check:**

1. **TierListBrowserScene** - Should still look correct (uses TypeScale already)
2. **ThemeLibraryOverlay** - Should still look correct
3. **AnalyticsSidebarView** - May have similar issues (separate task)

**Visual sweep:**

```bash
# Launch tvOS
./build_install_launch.sh tvos

# Test each overlay:
# 1. Toolbar → "New Tier List" (TierListProjectWizard)
# 2. Toolbar → "Themes" (ThemeLibrary)
# 3. Toolbar → "Analytics" (AnalyticsSidebar)
# 4. Select item → "Quick Move" (TierMoveSheet)

# Expected: No visual regressions, all overlays function normally
```

### Performance Testing

**Ensure no performance degradation:**

1. **Open HeadToHead overlay:**
   - Should appear instantly (<200ms)
   - No jank or stuttering

2. **Navigate with focus:**
   - Arrow keys should move focus smoothly
   - Focus animations should be fluid (60fps)

3. **Vote on multiple pairs:**
   - State updates should be immediate
   - No lag when advancing to next pair

**Instruments check (optional):**

```bash
# Profile in Xcode
# Product → Profile (Cmd+I)
# Template: Time Profiler
# Record while interacting with HeadToHead
# Look for: No new hot spots or excessive layout passes
```

---

## Expected Outcomes

### Visual Improvements

**Before remediation:**

- Fixed font sizes don't scale with Dynamic Type
- Inconsistent typography (mix of TypeScale and raw fonts)
- Fixed container dimensions clip text at large sizes
- Poor hierarchy on tvOS (text too small at 10-foot distance)

**After remediation:**

- All text scales gracefully with Dynamic Type settings
- Consistent typography hierarchy across all components
- Containers expand/contract with content
- Clear, readable hierarchy optimized for tvOS viewing distance
- iOS/macOS appropriately scaled for arm's length viewing

### Accessibility Compliance

- **Goal:** Meet WCAG 2.1 Level AA reflow expectations (text remains readable at 200% without losing content).
- **Goal:** Align with Apple accessibility guidance by ensuring every element that conveys information participates in Dynamic Type or `ScaledMetric`.
- **Goal:** Preserve tvOS-focused hierarchy (semantic text styles first, consistent focus affordances).

### Code Quality

- **Goal:** Achieve full AGENTS.md compliance by routing all typography through `TypeScale`.
- **Goal:** Apply `@ScaledMetric` (per Apple documentation) anywhere a frame/padding value should flex with accessibility settings.
- **Goal:** Normalize spacing via `Metrics.grid`/`TVMetrics` to keep overlays consistent and easier to audit.

### Metrics

**Pre-remediation snapshot:**

- Absolute point-size fonts (true Dynamic Type breaks): **3**
- Direct SwiftUI styles that bypass `TypeScale`: **10**
- Fixed dimensions: **6** locations
- Raw spacing literals: roughly **50 %** of spacing declarations

**Target state after remediation:**

- Absolute point-size fonts: **0** (all converted to tokens or `ScaledMetric`)
- Direct SwiftUI styles: **0** (all mapped to new `TypeScale` cases)
- Fixed dimensions: **0** (replaced with `@ScaledMetric` or flexible stacks)
- Raw spacing literals: **0** (expressed via metrics)

---

## Rollout Plan

### Commit Strategy

**Single atomic commit preferred:**

```bash
git add Tiercade/Design/DesignTokens.swift
git add Tiercade/Views/Overlays/HeadToHeadOverlay.swift
git add Tiercade/Views/Overlays/HeadToHeadOverlay+HelperViews.swift
git commit -m "fix(tvOS): implement Dynamic Type support in HeadToHead overlay

- Expand TypeScale with complete semantic hierarchy (h1-footnote + icon sizes)
- Add ScaledDimensions enum for accessibility-aware layout values
- Replace all hardcoded .font(.system(size:)) with TypeScale tokens
- Apply @ScaledMetric to all fixed frame dimensions
- Consolidate spacing to use Metrics.grid consistently

Fixes #<issue-number> (if applicable)

BREAKING CHANGE: TypeScale.metadata semantics changed
- Previous: Used for small metadata text
- Now: Used for emphasized stats/metrics
- Migration: Replace TypeScale.metadata → TypeScale.footnote for small text

Testing:
- All platforms build successfully
- Visual validation at standard and max Dynamic Type sizes
- No regressions in other overlays

Refs: AGENTS.md Design Tokens policy
Refs: Apple HIG - Dynamic Type guidelines"
```

**Alternative: Phased commits (if reviews requested per-phase):**

1. `feat(design): expand TypeScale and add ScaledDimensions`
2. `fix(headtohead): apply Dynamic Type to main overlay`
3. `fix(headtohead): apply Dynamic Type to helper views`
4. `refactor(headtohead): consolidate spacing to Metrics.grid`

### Documentation Updates

**After merging, update:**

1. **Tiercade/Design/README.md:**

   ```markdown
   ## Typography (NEW SECTION)

   ### Text Hierarchy

   Always use `TypeScale` tokens for consistent, accessible text:

   | Token | Purpose | tvOS Size | iOS Size |
   |-------|---------|-----------|----------|
   | `h1` | Hero headings | 96pt | 48pt |
   | `h2` | Overlay titles | 76pt | 34pt |
   | `h3` | Section headers | 57pt | 28pt |
   | `body` | Primary content | 38pt | 17pt |
   | `caption` | Small labels | 25pt | 11pt |
   | `footnote` | Metadata | 23pt | 13pt |

   > These base numbers come from the `TypeScale` expansion proposed in this document (tvOS values intentionally skew larger for the 10-foot experience); they are design targets, not copied from an Apple table.

   ### Icon Sizing

   Use `TypeScale.IconScale.*` with SF Symbols:

   ```swift
   Image(systemName: "star.fill")
       .imageScale(TypeScale.IconScale.medium)
   ```

   ### Dynamic Layout

   Use `@ScaledMetric` for dimensions that should scale:

   ```swift
   @ScaledMetric(relativeTo: .body) private var cardWidth = ScaledDimensions.candidateCardMinWidth

   CardView()
       .frame(minWidth: cardWidth)
   ```

2. **AGENTS.md (optional note):**

   ```markdown
   ### Dynamic Type Compliance

   All text must use `TypeScale` tokens. Never use hardcoded font sizes or direct SwiftUI font references (`.headline`, `.caption`, etc.) except for temporary prototypes.

   Layout dimensions that should scale with accessibility settings must use `@ScaledMetric` with a base value from `ScaledDimensions`.

   Example violations caught in review:
   - ❌ `.font(.system(size: 48, weight: .bold))`
   - ❌ `.frame(width: 240, height: 240)`
   - ❌ `.font(.headline)`

   Correct patterns:
   - ✅ `.imageScale(TypeScale.IconScale.medium)`
   - ✅ `@ScaledMetric private var size = ScaledDimensions.passTileSize`
   - ✅ `.font(TypeScale.caption)`
   ```

---

## Future Work (Out of Scope)

### Extend to Other Overlays

**Candidates for similar remediation:**

1. **AnalyticsSidebarView** - Likely has similar hardcoded typography
2. **TierListProjectWizard** - Multi-step form, may need ScaledMetric
3. **ThemeCreatorOverlay** - Color picker and text fields
4. **QuickRankOverlay** - Tier selection interface

**Estimated effort:** 1-2 hours each, following this playbook

### Advanced Dynamic Type

**Potential enhancements:**

1. **Dynamic column counts** - Reduce columns at large text sizes
2. **Alternate layouts** - Switch to vertical stack at accessibility sizes
3. **Text truncation strategies** - Smarter lineLimit based on Dynamic Type
4. **Performance optimization** - Cache ScaledMetric calculations

**References:**

- [Picking container views for your content](https://developer.apple.com/documentation/swiftui/picking-container-views-for-your-content/)
- [Size Classes](https://developer.apple.com/documentation/swiftui/environmentvalues/horizontalsizeclassclass/)

### SwiftLint Rule

**Prevent future violations:**

```yaml
# .swiftlint.yml
custom_rules:
  hardcoded_font_size:
    name: "Hardcoded Font Size"
    regex: '\.font\(\.system\(size:\s*\d+'
    message: "Use TypeScale tokens instead of hardcoded font sizes"
    severity: error

  hardcoded_spacing:
    name: "Hardcoded Spacing"
    regex: 'spacing:\s*\d+(?!\.)'
    message: "Use Metrics.grid expressions instead of raw spacing values"
    severity: warning
```

**Implementation:** Separate PR after this remediation merges

---

## Appendix

### Quick Reference: TypeScale Token Selection

**Decision tree:**

```text
Is this text...
├─ A major page/overlay title?          → h2
├─ A card title or section header?      → h3
├─ Primary body content/description?    → body
├─ A small label or button caption?     → caption
├─ Metadata, timestamps, fine print?    → footnote
├─ An emphasized metric or stat?        → metadata (bold, larger)
└─ Button label?                        → (Use Button's default, or label if custom)

Is this an icon...
├─ Hero/completion state?               → `TypeScale.IconScale.large`
├─ Primary action button?               → `TypeScale.IconScale.medium`
└─ Inline/decorative?                   → `TypeScale.IconScale.small`
```

### Quick Reference: ScaledMetric relativeTo

**Choose based on content inside:**

```swift
// Container holds title text
@ScaledMetric(relativeTo: .title) private var cardWidth = ...

// Container holds body text
@ScaledMetric(relativeTo: .body) private var buttonWidth = ...

// Container holds mixed content, use dominant style
@ScaledMetric(relativeTo: .headline) private var sectionHeight = ...
```

### Grep Patterns for Validation

```bash
# Find hardcoded font sizes (should return 0 after remediation)
grep -rn "\.font(.system(size: [0-9]" Tiercade/Views/Overlays/HeadToHead*.swift

# Find raw spacing literals (should return 0)
grep -rn "spacing: [0-9]" Tiercade/Views/Overlays/HeadToHead*.swift

# Find direct SwiftUI font references (should return 0)
grep -rn "\.font(\.\(headline\|body\|caption\|title\|largeTitle\)" Tiercade/Views/Overlays/HeadToHead*.swift | grep -v "TypeScale"

# Find fixed frame dimensions without ScaledMetric (manual review needed)
grep -rn "\.frame(.*width:.*[0-9]" Tiercade/Views/Overlays/HeadToHead*.swift
```

### Contact & Questions

**Implementation questions:**

- Refer to AGENTS.md Design Tokens section
- Check `Tiercade/Design/README.md` for design system patterns
- Review existing overlays (TierListBrowserScene) for reference implementations

**Testing issues:**

- Accessibility Inspector: Xcode → Open Developer Tool → Accessibility Inspector
- tvOS Simulator controls: I/O → Keyboard → Send Keyboard Input (arrow keys)
- Dynamic Type settings: Settings → Accessibility → Display & Text Size

---

**Document Version:** 1.0
**Last Updated:** 2025-11-12
**Author:** Claude (Anthropic)
**Status:** Ready for Implementation
