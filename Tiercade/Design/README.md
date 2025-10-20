# Tiercade Design System (Swift 6 language mode, Swift 6.2 toolchain, OS 26+, tvOS-first)

Design tokens and SwiftUI styles for Tiercade on the OS 26 baseline. Tokens are authored tvOS-first and fall back to adaptive system materials on iOS, iPadOS, and Mac Catalyst so a single definitions file supports every platform we ship.

## Files
- **DesignTokens.swift** – `Palette`, `Metrics`, `TypeScale`, and `Motion` helpers (dynamic colors + shared animations).
- **Styles.swift** – `card()`, `panel()`, `PrimaryButtonStyle`, `GhostButtonStyle`, `CardButtonStyle`, and `TVRemoteButtonStyle`.
- **GlassEffects.swift** – `tvGlassRounded`, `tvGlassCapsule`, and `tvGlassContainer` wrappers for [`glassEffect(_:in:)`](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)).
- **TVMetrics.swift** – tvOS spacing, layout, and card density helpers.
- **PlatformCardLayout.swift** – adaptive grid sizing and spacing for iOS, iPadOS, and Mac Catalyst cards.
- **VibrantDesign.swift** – tier badge utilities and `punchyFocus` modifier (colors sourced from `Palette`).
- **ThemeManager.swift** – user theme preference (`system`, `light`, `dark`) surfaced to the app shell.

## Surface Support Matrix

| Surface | Primary (tvOS 26+) | Fallback (iOS / iPadOS / Mac Catalyst) | Notes |
| --- | --- | --- | --- |
| Cards & collection cells | `.card()` + `tvGlassRounded()` or `GlassEffectContainer` when elevated | `.card()` + `.background(.ultraThinMaterial, in: RoundedRectangle)` | Avoid Liquid Glass on high-frequency scroll regions; default to `Palette.surface` for pagination-heavy grids. |
| Toolbars & overlays | `tvGlassContainer(spacing:)` + `.buttonStyle(.glass)` or custom `glassEffect` **ONLY on chrome** | Material stack (`.ultraThinMaterial`) matching the same shape | **⚠️ CRITICAL:** Apply glass to toolbar chrome ONLY, never to section backgrounds or containers. See warning below. |
| Buttons | `TVRemoteButtonStyle` or `.buttonStyle(.glassProminent)` for primary actions | `PrimaryButtonStyle` / `GhostButtonStyle` with system focus visuals | Keep minimum 4.5:1 text contrast and pair focus scale with shadow lift. |
| Section backgrounds | Solid backgrounds with `.background(Color.black.opacity(0.6))` + border overlays | Same solid pattern across platforms | **Never use glass effects on backgrounds** — they make focus overlays unreadable. |

### ⚠️ Critical: Glass Effects Must NOT Be Applied to Backgrounds

**Problem:** tvOS's built-in focus system applies overlay effects to text fields, keyboards, and focusable controls. When these overlays render through translucent glass backgrounds (`.tvGlassRounded()`, `.glassEffect()`, etc.), they become **completely unreadable**, appearing as illegible white films over text.

**Solution:** Glass effects belong **ONLY** on interactive UI chrome (toolbars, buttons, headers). Section backgrounds and containers must use **solid, opaque backgrounds**.

**Correct usage:**
```swift
// ✅ Glass on chrome/toolbar only
VStack(spacing: 0) {
    // Header with glass chrome
    HStack { /* toolbar buttons */ }
        .glassEffect(.regular, in: Rectangle())

    // Content with SOLID backgrounds
    ScrollView {
        VStack {
            TextField("Name", text: $name)
                .padding(12)
                .background(Color.black)  // Solid, not glass
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                }
        }
        .padding(20)
        .background(Color.black.opacity(0.6))  // Solid section background
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        }
    }
}
```

**Incorrect usage:**
```swift
// ❌ WRONG: Glass on section backgrounds
VStack {
    TextField("Name", text: $name)
    // ... other content
}
.padding(20)
.tvGlassRounded(20)  // ❌ Blocks focus overlays!
```

**Testing:** Always test text input and keyboard interaction in the tvOS simulator to verify that:
- Text field content is readable when focused
- Keyboard characters are visible when focused
- No translucent overlays obscure interactive elements

### Reduce Transparency & Contrast

Liquid Glass must fall back cleanly when people enable [`accessibilityReduceTransparency`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency/) or increase contrast. Our helpers mirror the pattern below:

```swift
@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

@ViewBuilder
func Surface<S: Shape>(_ shape: S, @ViewBuilder _ content: () -> some View) -> some View {
    if reduceTransparency {
        content().background(.thickMaterial, in: shape)
    } else {
        #if os(tvOS)
        content().glassEffect(.regular.interactive(), in: shape)
        #else
        content().background(.ultraThinMaterial, in: shape)
        #endif
    }
}
```

`tvGlassRounded` and `tvGlassContainer` already wrap this logic; prefer those helpers over hand-rolled materials so fallbacks stay consistent.

## Token Ledger

### Palette

| Token | Light | Dark | Intent | Contrast guidance |
| --- | --- | --- | --- | --- |
| `Palette.bg` | `#FFFFFF` | `#0B0F14` | Root background | ≥ 7:1 against `Palette.text` |
| `Palette.appBackground` | `#F5F7FA` | `#0E1114` | Full-scene background | Maintain AA with `Palette.cardText` |
| `Palette.surface` | `#F8FAFC` | `#0F141A` | Cards, panels, trays | Maintain AA (4.5:1) with `Palette.text` |
| `Palette.cardBackground` | `#FFFFFF` | `#192028` | High-frequency content surfaces | Use `Palette.cardText` tokens for legibility |
| `Palette.surfHi` | `#00000008` | `#FFFFFF14` | Subtle overlays, separators | Use for hairline strokes only |
| `Palette.stroke` | `#00000010` | `#FFFFFF14` | Card outlines & chrome separators | Blend subtly with background |
| `Palette.text` | `#111827` | `#E8EDF2` | Primary text | AAA for body text on `Palette.surface` |
| `Palette.textDim` | `#6B7280` | `#FFFFFFB8` | Secondary text, metadata | Pair with at least 3:1 contrast for metadata |
| `Palette.cardText` | `#0E1114` | `#FFFFFFE6` | Text on `Palette.cardBackground` | Ensure AA ≥ 4.5:1 against card surfaces |
| `Palette.cardTextDim` | `#4B5563` | `#FFFFFFA6` | Metadata on card surfaces | Pair with icons when below 3:1 |
| `Palette.textDisabled` | `#9CA3AF` | `#FFFFFF66` | Disabled labels and hints | Reserve for non-interactive text |
| `Palette.brand` | `#3B82F6` | `#3B82F6` | Accents, focus chrome | When used on text, pair with dark material |
| `Palette.tierColors` | Tier labels (`S`, `A`, `B`, `C`, `D`, `F`, `UNRANKED`) | Same | Tier chroma and badges | Ensure text overlays maintain AA contrast |

Tier accents live in `Palette.tierColors`; never recreate tier color maps—import from `TiercadeCore` when you need metadata for history or export pipelines.

> `VibrantDesign.swift` reuses these palette entries for tier badges and focus effects—`Palette` is the single source of truth for colors across the app.

### Metrics

| Token | Value | Usage |
| --- | --- | --- |
| `Metrics.grid` | `8pt` | Base spacing unit (8-pt grid) |
| `Metrics.rSm` / `rMd` / `rLg` | `8 / 12 / 16 pt` | Corner radii for surfaces and cards |
| `Metrics.cardMin` | `140×180` | Minimum card footprint to keep metadata readable |
| `Metrics.paneLeft` / `paneRight` | `280 / 320` | Inspector split widths |
| Toolbar sizing | tvOS uses `toolbarButtonSize = 48`, `toolbarIconSize = 36`; other platforms fall back to `44` / `24` | Aligns with tvOS focus hit regions |

Reference `Metrics` instead of scattering literals so updates (like density tweaks) stay centralized.

### TypeScale

`TypeScale` exposes semantic fonts backed by system styles, so they automatically scale with Dynamic Type ([`dynamicTypeSize(_:)`](https://developer.apple.com/documentation/swiftui/view/dynamictypesize(_:))).

| Token | tvOS | iOS / iPadOS / Catalyst | Notes |
| --- | --- | --- | --- |
| `TypeScale.h2` | `.largeTitle.bold()` | `.title.semibold()` | Tier list headers, overlay titles |
| `TypeScale.h3` | `.title.semibold()` | `.title2.semibold()` | Card titles, sidebar headers |
| `TypeScale.body` | `.title3` | `.body` | Default body copy |
| `TypeScale.label` | `.body` | `.caption` | Buttons, compact labels |
| `TypeScale.metadata` | `.title3.semibold()` | `.subheadline.semibold()` | Tier metadata, chip labels |

### TVMetrics

Key values from `TVMetrics` drive overlay and grid layout:

| Token | Value | Purpose |
| --- | --- | --- |
| `overlayPadding` | `60` | Inner padding for modal overlays |
| `overlayCornerRadius` | `24` | Default overlay curvature |
| `toolbarClusterSpacing` | `12` | Space between glass clusters |
| `contentTopInset` | `max(topBarHeight, safeArea) + 12` | Aligns primary grid with toolbar glass |
| `cardLayout(for:)` | Density-aware grid sizing | Picks one of six presets based on item count |
| Focus scale (see `TVRemoteButtonStyle`) | `1.06` | Max focus scale before halo clipping |

### Motion

We standardise animation timing so interactions feel predictable:

| Token | Duration / Spring | Used by | Notes |
| --- | --- | --- | --- |
| `Motion.fast` | `0.12s easeOut` | `PrimaryButtonStyle` press feedback | Keep < 0.16s for tap acknowledgement |
| `Motion.focus` | `0.15s easeOut` | `TVRemoteButtonStyle` focus transitions | Matches tvOS focus halo cadence |
| `Motion.emphasis` | `0.20s easeOut` | `GhostButtonStyle`, `CardButtonStyle` | Use for scale + shadow lifts |
| `Motion.spring` | `spring(response: 0.30, dampingFraction: 0.8)` | Overlay morphs & Liquid Glass transitions | Ensure the first meaningful frame stays under ~120 ms |

Always respect [`accessibilityReduceMotion`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion/)—our styles already bail out of animations when it is enabled.
All animation helpers live in `Motion` (DesignTokens.swift); prefer `Motion.fast`, `Motion.focus`, `Motion.emphasis`, and `Motion.spring` over hard-coded durations.

## Focus-aware Styles

All interactive surfaces must respond to the following states: **normal**, **focused**, **pressed**, **disabled**, and **selected**. tvOS focus drives both `@Environment(\.isFocused)` and `@FocusState`—use both to keep visuals and logic aligned.

- Wrap focus regions in [`focusSection()`](https://developer.apple.com/documentation/swiftui/view/focussection()/) so the Siri Remote can move predictably across overlays.
- Use [`focusable(interactions: .activate)`](https://developer.apple.com/documentation/swiftui/view/focusable(_:interactions:)/) for button-like views to opt into the new multi-mode focus model.
- Default focus should be declared with [`prefersDefaultFocus(_:in:)`](https://developer.apple.com/documentation/swiftui/view/prefersdefaultfocus(_:in:)/) and a scoped [`FocusState`](https://developer.apple.com/documentation/swiftui/focusstate) when overlays appear.

Example wrapper for focus-aware cards:

```swift
struct FocusableCard<Content: View>: View {
    @Environment(\.isFocused) private var isFocused
    let content: () -> Content

    var body: some View {
        content()
            .card()
            .scaleEffect(isFocused ? 1.06 : 1.0)
            .shadow(color: isFocused ? Palette.brand.opacity(0.35) : .black.opacity(0.12),
                    radius: isFocused ? 22 : 12,
                    y: isFocused ? 12 : 6)
            .focusable(interactions: .activate)
    }
}
```

Pair this wrapper with `tvGlassContainer` when a set of cards needs shared Liquid Glass halos.

### `punchyFocus` modifier

For tier-colored cards that use custom focus halos, apply the `punchyFocus(tier:cornerRadius:)` helper from `VibrantDesign.swift`:

```swift
CardView(...)
    .punchyFocus(tier: .s, cornerRadius: 16)
```

On tvOS this adds a dual-ring Liquid Glass halo and tier-specific glow; on iOS/macOS it falls back to a subtle border pulse. The modifier automatically respects `accessibilityReduceMotion`.

## Button Styles

- **`PrimaryButtonStyle`** – High-contrast primary action. Uses `TypeScale.label`, `Palette.brand`, and `Motion.fast` for press feedback. On tvOS, text flips to black while pressed to maintain contrast.
- **`GhostButtonStyle`** – Neutral actions, filters, and secondary overlay controls. Uses `Palette.brand` tinting for focus states and disables motion when accessibility reduce motion is enabled.
- **`CardButtonStyle`** – Applies scale and shadow lift for card-like buttons using `Motion.emphasis`. Combine with `.card()` for selection grids.
- **`TVRemoteButtonStyle`** – Liquid Glass button palette with three roles (`primary`, `secondary`, `list`). Applies `glassEffect(.regular.tint(palette.tint).interactive())`, per-role tinting, and motion tuned for tvOS focus halos.

All button styles avoid communicating state through color alone—focus adds weight, border glow, or scale so Reduce Transparency users still get clear affordances.

## Iconography & SF Symbols

- Prefer SF Symbols with `.symbolRenderingMode(.hierarchical)` or `.palette` to maintain contrast on glass.
- Use `.font(.system(size: Metrics.toolbarIconSize, weight: .semibold))` for toolbar glyphs to align with focus halos.
- Avoid ultra-thin weights on tvOS—the Apple TV leads with bold, high-contrast glyphs. Reference Apple’s [SF Symbols design guidance](https://developer.apple.com/design/human-interface-guidelines/sf-symbols/overview/) when adding new assets.

## Accessibility Checkpoints

- **Dynamic Type** – `TypeScale` uses system fonts; verify large text layouts with `.dynamicTypeSize(.large ... .accessibility3)` and text truncation rules.
- **Contrast** – Ensure text on `Palette.surface` hits WCAG AA (4.5:1); metadata on `Palette.surfHi` requires supporting icons or bold weight for clarity.
- **Reduce Transparency** – `tvGlassRounded` and `tvGlassContainer` fallback to `.thickMaterial` / `.ultraThinMaterial` when [`accessibilityReduceTransparency`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducetransparency/) is true. Never apply semi-transparent fills manually.
- **Reduce Motion** – Short-circuit animations when [`accessibilityReduceMotion`](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion/) is enabled.
- **Focus order** – Group overlays with `focusSection()` and land default focus using `@FocusState`. Re-evaluate defaults with `resetFocus(in:)` when the dataset changes.
- **Hit testing** – Disable background interaction via [`allowsHitTesting(false)`](https://developer.apple.com/documentation/swiftui/view/allowshittesting(_:)/) instead of `.disabled(true)` so VoiceOver retains focus routing.
- **Identifiers** – Apply [`accessibilityIdentifier(_:)`](https://developer.apple.com/documentation/swiftui/view/accessibilityidentifier(_:)) to leaf controls using the `{Component}_{Action}` pattern (`Toolbar_H2H`, `QuickMove_Overlay`, etc.)—never attach IDs to containers with `.accessibilityElement(children: .contain)`.

## Usage Examples

### Inspector overlay with Liquid Glass

```swift
struct InspectorOverlay: View {
    var body: some View {
        tvGlassContainer {
            VStack(alignment: .leading, spacing: Metrics.grid * 3) {
                Text("Inspector")
                    .font(TypeScale.h3)
                    .foregroundStyle(Palette.text)

                Button("Apply") { /* action */ }
                    .buttonStyle(PrimaryButtonStyle())
                Button("Cancel") { /* action */ }
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(Metrics.grid * 4)
            .tvGlassRounded(28)
            .focusSection()
            .accessibilityElement(children: .contain)
        }
        .padding(TVMetrics.overlayPadding)
    }
}
```

### Focusable card grid cell

```swift
struct CardCell: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Metrics.grid * 2) {
                Text(title)
                    .font(TypeScale.metadata)
                    .foregroundStyle(Palette.text)
            }
            .frame(minWidth: Metrics.cardMin.width,
                   minHeight: Metrics.cardMin.height)
            .card()
        }
        .buttonStyle(CardButtonStyle())
        .focusable(interactions: .activate)
    }
}
```

## Do & Don’t

- **Do** apply Liquid Glass to chrome, overlays, and focusable controls; keep scrollers on solid surfaces for performance.
- **Do** centralise spacing, radii, and typography through `Metrics`, `TVMetrics`, and `TypeScale`.
- **Do** toggle `.allowsHitTesting(false)` on background layers when overlays appear so VoiceOver and inertia remain responsive.
- **Don’t** hardcode tier colors—use `Palette.tierColor(_:)` or the map from `TiercadeCore`.
- **Don’t** communicate state with color alone; pair it with scale, border, or iconography.

## Cross-links

- tvOS focus, overlays, and build steps: see [`AGENTS.md` § tvOS UX & Focus Management](../../AGENTS.md#tvos-ux--focus-management).
- Head-to-head and overlay exit contract: [`AGENTS.md` overlay guidance](../../AGENTS.md#head-to-head-matchup-arena-overlay-specifics).
- Core models and deterministic helpers: [`TiercadeCore/README.md`](../../TiercadeCore/README.md).
