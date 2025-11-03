# Tiercade Tier System Flexibility Analysis & Remediation Plan

**Date**: 2025-11-03
**Status**: Planning
**Priority**: High
**Estimated Effort**: 3-5 days

---

## Executive Summary

**Current State**: The Tiercade codebase has **partial** support for custom tiers, with significant hardcoded dependencies on the S,A,B,C,D,F tier system across 8+ critical areas.

**Risk Assessment**: 🔴 **HIGH** - Custom tier names, ordering, or variable tier counts would cause:
- Export failures (missing custom tiers)
- UI inconsistencies (wrong colors, missing menu items)
- Analysis errors (incomplete statistics)
- Import data loss (custom tiers ignored)

**Good News**: Core logic (TierLogic, HeadToHeadLogic) is already tier-agnostic. State management has `tierOrder`, `tierLabels`, and `tierColors` properties designed for flexibility, but they're not being consistently used.

**Effort Required**: **MEDIUM** (~8 files, ~15 targeted changes, no architecture redesign needed)

---

## Evidence-Based Findings

### 🔴 Critical Issues (Blockers for Custom Tiers)

#### 1. **Hardcoded State Initialization**
**Location**: `Tiercade/State/TierListState.swift:21-24`
```swift
var tiers: Items = ["S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []]
var tierOrder: [String] = ["S", "A", "B", "C", "D", "F"]
```

**Impact**:
- ❌ Custom tier names: Must manually replace all 6 entries
- ❌ Custom ordering: Must manually reorder array
- ⚠️ Variable count: Works but requires manual initialization

**Evidence**: Every new tier list starts with SABCDF, even if the user wants "Gold/Silver/Bronze"

---

#### 2. **Export System Ignores Current Tier Configuration**
**Location**: `Tiercade/State/AppState+Export.swift:48-57, 113-120`
```swift
private func buildDefaultTierConfig() -> TierConfig {
    [
        "S": TierConfigEntry(name: "S", description: nil),
        "A": TierConfigEntry(name: "A", description: nil),
        // ... hardcoded SABCDF only
    ]
}
```

**Impact**:
- ❌ Custom tier names: Always export as S,A,B,C,D,F
- ❌ Custom ordering: Always export in SABCDF order
- ❌ Variable count: Only exports 6 tiers + unranked
- ❌ Ignores `tierLabels` state completely

**Evidence**: Text/JSON/Markdown exports use `buildDefaultTierConfig()` instead of reading `app.tierOrder` and `app.tierLabels`

---

#### 3. **Toolbar Menu Hardcoded**
**Location**: `Tiercade/Views/Toolbar/ContentView+Toolbar.swift:540`
```swift
ForEach(["S", "A", "B", "C", "D", "F"], id: \.self) { tier in
    let isTierEmpty = (app.tiers[tier]?.isEmpty ?? true)
    Button("Clear \(tier) Tier") { app.clearTier(tier) }
        .disabled(isTierEmpty)
}
```

**Impact**:
- ❌ Custom tier names: Won't appear in "Clear Tier" menu
- ❌ Custom ordering: Menu always shows SABCDF order
- ❌ Variable count: Menu always shows exactly 6 options

**Evidence**: Menu doesn't reference `app.tierOrder`, so adding a 7th tier won't show it

---

#### 4. **CSV Import Hardcoded**
**Location**: `Tiercade/State/AppState+Import.swift:61-63`
```swift
var newTiers: Items = [
    "S": [], "A": [], "B": [], "C": [], "D": [], "F": [], "unranked": []
]
```

**Impact**:
- ❌ Custom tier names: CSV with "Excellent/Good/Bad" tiers won't import correctly
- ❌ Variable count: Extra tiers in CSV ignored

**Evidence**: Import creates fresh SABCDF structure regardless of CSV content. Unknown tier names from CSV aren’t added to `tierOrder`, which later causes analysis/export omissions.

---

#### 5. NEW: Type-safe conversion collapses unknown tiers to unranked (data loss risk)
**Location**: `TiercadeCore/Sources/TiercadeCore/Models/TierIdentifier.swift:90-103`
```swift
extension Dictionary where Key == String, Value == [Item] {
    public func toTyped() -> TypedItems {
        var typed: TypedItems = [:]
        for (key, value) in self {
            if let tier = TierIdentifier(rawValue: key) {
                typed[tier] = value
            } else {
                // Preserve unknown keys by mapping to closest match or unranked
                typed[.unranked, default: []].append(contentsOf: value)
            }
        }
        return typed
    }
}
```

**Impact**:
- ❌ Custom tier names: Items in non-letter tiers may be collapsed into `unranked` when `toTyped()` is used
- ⚠️ Downstream consumers (tests/experimental paths) that adopt `TypedItems` can silently misclassify

**Mitigation**:
- Treat `toTyped()` as migration/testing-only; avoid in runtime paths with custom tiers OR adjust implementation to preserve unknown keys (future enhancement).

---

### 🟡 Medium Issues (Degrades Experience)

#### 5. **Design Tokens Use Static Color Lookup**
**Location**: `Tiercade/Design/DesignTokens.swift:53-67`
```swift
internal static let tierColors: [String: Color] = [
    "S": Color(designHex: "#E11D48"),
    "A": Color(designHex: "#F59E0B"),
    // ... only SABCDF defined
]

internal static func tierColor(_ tier: String) -> Color {
    let normalized = tier.lowercased()
    if normalized == "unranked" { return unrankedTierColor }
    return tierColors[tier.uppercased()] ?? defaultTierColor  // Falls back to gray
}
```

**Impact**:
- ❌ Custom tier names: All render as gray (`defaultTierColor`)
- ✅ Custom ordering: No impact (keyed by name)

**Evidence**: `AppState.tierColors: [String: String]` exists but isn't used by design tokens

**Apple Documentation Reference**: Swift's type-safe key-path system (`\TierListState.tierColors`) would enable dynamic lookups. Current static dictionary pattern prevents runtime flexibility.

---

#### 6. REVISED: Theme system is generally variable-length friendly; verify mapping is used consistently
**Location**: `Tiercade/Design/TierTheme.swift` and `Tiercade/State/ThemeState.swift`
```swift
internal func colorHex(forRank identifier: String, fallbackIndex: Int? = nil) -> String {
    if identifier.lowercased() == "unranked" { return unrankedColorHex }
    if let direct = colorHex(forIdentifier: identifier) { return direct }
    if let fallbackIndex, let indexed = colorHex(forRankIndex: fallbackIndex) { return indexed }
    return Self.fallbackColor
}
```

**Impact (updated)**:
- ✅ Custom tier names: Supported via `colorHex(forIdentifier:)`
- ✅ Custom ordering: Positional fallback supported via `fallbackIndex`
- ⚠️ Variable count: If tiers exceed theme ranks, falls back to `fallbackColor` — UX can be improved by repeating last color

---

#### 7. **TierIdentifier Enum is Exhaustive**
**Location**: `TiercadeCore/Sources/TiercadeCore/Models/TierIdentifier.swift:24-31`
```swift
public enum TierIdentifier: String, Codable, Sendable, CaseIterable {
    case s = "S"
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"
    case f = "F"
    case unranked = "unranked"
}
```

**Impact**:
- ❌ Custom tier names: Cannot be represented in enum
- ❌ Variable count: Fixed at 7 cases

**NOTE**: This enum is **opt-in** for type safety. The codebase uses string-based `Items = [String: [Item]]` everywhere, so custom tiers work in practice. The enum exists for APIs that want compile-time safety but isn't enforced globally.

**Apple Documentation Reference**: SwiftData Schema documentation shows dynamic schema approaches using `@Model` with runtime property inspection. The current `TierIdentifier` enum approach is inherently static.

---

#### 8. **Analysis Iteration**
**Location**: `Tiercade/State/AppState+Analysis.swift:80, 93-99`
```swift
let unrankedCount = tiers["unranked"]?.count ?? 0

private func tierDistribution(totalCount: Int) -> [TierDistributionData] {
    tierOrder.compactMap { tier in
        let count = tiers[tier]?.count ?? 0
        // ...
    }
}
```

**Impact**:
- ⚠️ Custom tier names: Stats correct IF `tierOrder` updated
- ✅ Custom ordering: Stats follow `tierOrder`
- ❌ Variable count: If tier exists but not in `tierOrder`, excluded from stats

**Note**: This component already uses `tierOrder` dynamically, but depends on upstream fixes to work correctly.

---

#### 9. NEW: Card focus halo and colors assume letter tiers
**Locations**: `Tiercade/Views/Main/ContentView+TierGrid.swift:268-279`, `Tiercade/Design/VibrantDesign.swift:32-51`, `Tiercade/Views/Main/ContentView+TierRow.swift:201-209`

**Impact**:
- ❌ Custom tier names: Focus halo falls back to `.unranked`/default colors
- ❌ Variable count: No dynamic mapping

**Mitigation**:
- Introduce `.punchyFocus(color:)` and compute `Color` from `app.displayColorHex(for:)` with Palette fallback; stop using fixed `Tier` enum for runtime data.

---

#### 10. NEW: QuickMove overlay focus fallback assumes "S"
**Location**: `Tiercade/Views/Overlays/QuickMoveOverlay.swift:188-196`

**Mitigation**: Replace `"S"` with `TierIdentifier.unranked.rawValue` fallback.

---

#### 11. NEW: Minor UI letter references (cosmetic)
**Locations**: `Tiercade/Views/Components/InspectorView.swift`, wizard preview labels

**Action**: Prefer state-driven colors when practical.

---

### ✅ Already Flexible (No Changes Needed)

These components already support custom tiers:

1. **Tier Grid order iteration** (`ContentView+TierGrid.swift`) - Uses `ForEach(tierOrder, id: \.self)` (note: card halo color still needs fix in Finding 9)
2. **Head-to-Head Logic** (`HeadToHead.swift`) - Accepts `tierOrder` parameter, uses quantile distribution
3. **TierLogic** (`TierLogic.swift`) - Searches all tiers dynamically via `for (name, arr) in tiers`
4. **Tier List Creator/Wizard** - Supports fully custom tier names, colors, ordering
5. **AI Generation** - Tier-agnostic, only generates items

---

## Proposed Solution Architecture

### Core Principles

1. **Single Source of Truth**: `TierListState` properties (`tierOrder`, `tierLabels`, `tierColors`) drive ALL tier-related behavior
2. **Default to SABCDF**: Maintain backward compatibility by defaulting to standard tiers
3. **No Breaking Changes**: All changes are additive or internal refactors
4. **Tier-Agnostic APIs**: All functions accept `tierOrder` instead of assuming SABCDF

### Key Design Patterns

**Pattern 1: Initialize from Schema**
```swift
// TierListState.swift - NEW
internal init(tierOrder: [String] = TierIdentifier.rankedTiers.map(\.rawValue)) {
    self.tierOrder = tierOrder
    var tiers: Items = ["unranked": []]
    for tier in tierOrder {
        tiers[tier] = []
    }
    self.tiers = tiers
}
```

**Pattern 2: Build Export Config from State**
```swift
// AppState+Export.swift - REPLACE buildDefaultTierConfig()
private func buildTierConfig() -> TierConfig {
    var config: TierConfig = [:]
    for tier in tierOrder {
        let label = tierLabels[tier] ?? tier
        config[tier] = TierConfigEntry(name: label, description: nil)
    }
    return config
}
```

**Pattern 3: Use State-Driven UI**
```swift
// ContentView+Toolbar.swift - REPLACE hardcoded array
ForEach(app.tierOrder, id: \.self) { tier in
    let isTierEmpty = (app.tiers[tier]?.isEmpty ?? true)
    Button("Clear \(app.displayLabel(for: tier))") { app.clearTier(tier) }
        .disabled(isTierEmpty)
}
```

**Pattern 4: Dynamic Color Lookup**
```swift
// DesignTokens.swift - NEW helper
internal static func tierColor(_ tier: String, from state: [String: String]) -> Color {
    if tier.lowercased() == "unranked" { return unrankedTierColor }
    if let hex = state[tier] {
        return ColorUtilities.color(hex: hex)
    }
    // Fallback to static colors for backward compatibility
    return tierColors[tier.uppercased()] ?? defaultTierColor
}
```

**Apple Documentation Context**: This follows SwiftUI's environment-driven design patterns. Rather than static lookups, pass dynamic state through view hierarchy via `@Observable` classes (as we already do with `AppState`).

Additional references (for dynamic lists and focus management):
- SwiftUI ForEach (dynamic collections): https://developer.apple.com/documentation/swiftui/foreach/
- SwiftUI FocusState (keyboard/remote focus): https://developer.apple.com/documentation/swiftui/focusstate/

---

## Implementation Plan (Phased Approach)

### Phase 1: State & Initialization (Priority: 🔴 Critical)

**Files to Modify**:
1. `Tiercade/State/AppState+Items.swift`
2. `Tiercade/State/TierListState.swift` (doc-only note)

**Changes (low-risk)**:
```swift
// AppState+Items.swift
// REPLACE makeEmptyTiers() with a dynamic builder
private func makeEmptyTiers() -> Items {
    var result: Items = [:]
    for name in tierOrder { result[name] = [] }
    result["unranked"] = []
    return result
}

// TierListState.swift (doc): prefer deriving empty tiers from current tierOrder
```

**Testing**:
- ✅ Fresh initialization uses `tierOrder` for keys (no letters required)
- ✅ Verify `tiers` contains all custom tier keys + `unranked`

---

### Phase 2: Export System (Priority: 🔴 Critical)

**Files to Modify**:
1. `Tiercade/State/AppState+Export.swift`

**Changes**:
```swift
// REPLACE buildDefaultTierConfig() and all usages
private func buildTierConfig() -> TierConfig {
    var config: TierConfig = [:]
    for tier in tierOrder {
        let label = tierLabels[tier] ?? tier
        config[tier] = TierConfigEntry(name: label, description: nil)
    }
    return config
}

// UPDATE all export methods to use buildTierConfig() instead of buildDefaultTierConfig()
// Lines to update: 48-57, 113-120, 134-142, 164-172

// ALSO: Avoid dropping tiers in core formatter when config entry is missing
// TiercadeCore/Sources/TiercadeCore/Utilities/Formatters.swift
// BEFORE:
// guard let cfg = tierConfig[tier], !items.isEmpty else { return nil }
// AFTER:
let label = (tierConfig[tier]?.name) ?? tier
guard !items.isEmpty else { return nil }
return "\(label) Tier (\(tierConfig[tier]?.description ?? "")): \(names)"
```

**Testing**:
- ✅ Export with custom tier names preserves labels
- ✅ Export with 3-tier system includes all 3
- ✅ Export with 10-tier system includes all 10
- ✅ JSON/Text/Markdown/CSV all use dynamic config

---

### Phase 3: UI Components (Priority: 🔴 Critical)

**Files to Modify**:
1. `Tiercade/Views/Toolbar/ContentView+Toolbar.swift`
2. `Tiercade/Views/Main/ContentView+TierGrid.swift` (verify already dynamic)

**Changes**:
```swift
// ContentView+Toolbar.swift:540
// REPLACE:
ForEach(["S", "A", "B", "C", "D", "F"], id: \.self) { tier in

// WITH:
ForEach(app.tierOrder, id: \.self) { tier in
    let isTierEmpty = (app.tiers[tier]?.isEmpty ?? true)
    Button("Clear \(app.displayLabel(for: tier))") {
        app.clearTier(tier)
    }
    .disabled(isTierEmpty)
}
```

**Testing**:
- ✅ Toolbar "Clear Tier" menu shows all custom tiers
- ✅ Menu respects custom tier ordering
- ✅ Menu shows custom tier labels (not internal IDs)

Additional UI fixes in this phase:

1) Card focus halo decoupled from letter tiers
```swift
// VibrantDesign.swift
// ADD: color-based focus variant
internal struct PunchyFocusStyleDynamic: ViewModifier {
    let color: Color; let cornerRadius: CGFloat
    @Environment(\.isFocused) private var isFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        #if os(tvOS)
        content
            .scaleEffect(isFocused ? 1.07 : 1.0)
            .shadow(color: color.opacity(isFocused ? 0.55 : 0.0), radius: isFocused ? 28 : 0)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(color.opacity(isFocused ? 0.95 : 0.0), lineWidth: 4))
            .animation(reduceMotion ? nil : Motion.spring, value: isFocused)
        #else
        content
            .scaleEffect(isFocused ? 1.05 : 1.0)
            .shadow(color: color.opacity(isFocused ? 0.22 : 0.0), radius: isFocused ? 24 : 0)
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(Color.white.opacity(isFocused ? 0.16 : 0.0), lineWidth: 2))
            .animation(reduceMotion ? nil : Motion.spring, value: isFocused)
        #endif
    }
}

internal extension View {
    func punchyFocus(color: Color, cornerRadius: CGFloat = 12) -> some View {
        modifier(PunchyFocusStyleDynamic(color: color, cornerRadius: cornerRadius))
    }
}

// ContentView+TierGrid.swift / ContentView+TierRow.swift
// REPLACE
.punchyFocus(tier: tierForItem(item), cornerRadius: ...)
// WITH
let hex = app.displayColorHex(for: currentTierId)
let color = hex.flatMap(Color.init(hex:)) ?? Palette.tierColor(currentTierId)
.punchyFocus(color: color, cornerRadius: ...)
```

2) QuickMove overlay fallback does not assume "S"
```swift
// QuickMoveOverlay.swift:195-196
// BEFORE: focusedElement = .tier(allTiers.first ?? "S")
// AFTER:  focusedElement = .tier(allTiers.first ?? TierIdentifier.unranked.rawValue)
```
- ✅ Grid rendering remains correct (already uses `tierOrder`)

---

### Phase 4: Import System (Priority: 🔴 Critical)

**Files to Modify**:
1. `Tiercade/State/AppState+Import.swift`

**Changes**:
```swift
// importCSV method (~line 61)
// OPTION A: Initialize from current tierOrder
var newTiers: Items = [TierIdentifier.unranked.rawValue: []]
for tier in tierOrder {
    newTiers[tier] = []
}

// OPTION B (more advanced): Detect tiers from CSV headers
// Parse CSV to find "Tier" column values, build tierOrder dynamically
// This allows importing a CSV with completely different tier structure
```

**Testing**:
- ✅ Import CSV with custom tier names ("Tier" column values)
- ✅ Import preserves items in correct tiers
- ✅ Import with 3-tier CSV works
- ✅ Import with 10-tier CSV works

---

### Phase 5: Design Tokens & Colors (Priority: 🟡 Medium)

**Files to Modify**:
1. `Tiercade/Design/DesignTokens.swift`
2. Update all view code passing `app.tierColors` to design token helpers

**Changes**:
```swift
// DesignTokens.swift
// ADD: State-driven color lookup
internal static func tierColor(_ tier: String, from stateColors: [String: String]) -> Color {
    // Check state colors first (custom tier colors)
    if let hex = stateColors[tier] {
        return ColorUtilities.color(hex: hex)
    }

    // Fallback to static colors (SABCDF defaults)
    if tier.lowercased() == "unranked" { return unrankedTierColor }
    return tierColors[tier.uppercased()] ?? defaultTierColor
}

// Views call: Palette.tierColor(tier, from: app.tierColors)
```

**Alternative (Simpler)**: Views already have access to `app.displayColorHex(for:)`. Use that directly instead of design tokens for tier colors.

**Testing**:
- ✅ Custom tier colors render correctly
- ✅ SABCDF tiers still use default colors if `tierColors` empty
- ✅ Fallback to gray for unknown tiers works

---

### Phase 6: Theme System (Priority: 🟡 Medium)

**Files to Modify**:
1. `Tiercade/Design/TierTheme.swift`
2. `Tiercade/State/AppState+Theme.swift`

**Changes**:
```swift
// TierTheme.swift
// ADD: Support for variable-length tier themes
// OPTION A: Allow themes to have 3-10 tiers, pad/truncate as needed
// OPTION B: Themes remain 6 tiers, but apply dynamically based on tierOrder length

// AppState+Theme.swift
internal func applyCurrentTheme() {
    let themeColors = theme.selectedTheme.rankedTiers

    // Map theme colors to current tierOrder
    var newColors: [String: String] = [:]
    for (index, tier) in tierOrder.enumerated() {
        if index < themeColors.count {
            newColors[tier] = themeColors[index].colorHex
        } else {
            // Fallback: repeat last color or use default
            newColors[tier] = TierTheme.fallbackColor
        }
    }
    tierColors = newColors

    // Unranked tier color
    tierColors[TierIdentifier.unranked.rawValue] = theme.selectedTheme.unrankedColorHex

    persistence.hasUnsavedChanges = true
}
```

**Testing**:
- ✅ Apply 6-tier theme to 3-tier list (uses first 3 colors)
- ✅ Apply 6-tier theme to 10-tier list (repeats or fallback colors)
- ✅ Theme application respects tierOrder

---

### Phase 7: Analysis & Statistics (Priority: 🟢 Low)

**Files to Modify**:
1. `Tiercade/State/AppState+Analysis.swift`

**Changes**:
```swift
// tierDistribution method already uses tierOrder - verify it works
private func tierDistribution(totalCount: Int) -> [TierDistributionData] {
    tierOrder.compactMap { tier in
        let count = tiers[tier]?.count ?? 0
        guard count > 0 else { return nil }
        let percentage = totalCount > 0 ? Double(count) / Double(totalCount) * 100 : 0
        return TierDistributionData(
            tier: displayLabel(for: tier),  // Use custom label
            count: count,
            percentage: percentage
        )
    }
}
```

**Issue**: Current code already uses `tierOrder`, so it should work. **Verify** it uses `displayLabel(for:)` instead of raw tier ID.

**Testing**:
- ✅ Analysis shows correct counts for custom tiers
- ✅ Analysis uses custom tier labels
- ✅ Analysis handles variable tier counts

---

## Reviewer Addendum: Migration & Backward Compatibility

- `TypedItems` conversion (`toTyped()`) must not be used in runtime flows that need full custom-tier preservation; if unavoidable, revisit its behavior to avoid collapsing unknown keys into `unranked`.
- Keep `TierIdentifier` for reserved `unranked` and legacy paths only; avoid expanding its use in new flexible features.
- Export formatters should never drop tiers if `TierConfig` is absent; fall back to the tier’s id/label string.
- CSV import must create missing tiers and populate `tierOrder` in first-seen order (excluding `unranked`).
- UI should prioritize `app.displayColorHex(for:)`/state colors over static Palette letter colors; Palette acts as a fallback only.

## Reviewer Addendum: Risk Updates

- High: Potential data loss/misclassification if `toTyped()` is applied to custom tiers (mitigation: policy + implementation guard)
- Medium: Card halo color inconsistent for custom tiers (mitigation: color-based `punchyFocus`)
- Medium: QuickMove overlay focus fallback wrongly assumes "S" (mitigation: use `unranked` or first tier)

## Reviewer Addendum: Success Criteria (Augmented)

- [ ] CSV import creates tiers dynamically and sets `tierOrder` accordingly
- [ ] Exporters include all tiers with proper labels; no letter-only defaults
- [ ] Toolbar menu enumerates `app.tierOrder` and displays labels
- [ ] Card focus halo uses per-tier color from state (no letter coupling)
- [ ] QuickMove overlay uses safe fallback (first tier or `unranked`), never hardcodes "S"
- [ ] No production path uses `toTyped()` in ways that collapse custom tiers

## Apple Docs References (Consulted)

- SwiftUI ForEach (dynamic content): https://developer.apple.com/documentation/swiftui/foreach/
- SwiftUI FocusState (focus management): https://developer.apple.com/documentation/swiftui/focusstate/

---

## Testing Strategy

### Unit Tests (TiercadeCore)

**New Test File**: `TiercadeCore/Tests/TiercadeCoreTests/CustomTierTests.swift`

```swift
@Test("TierLogic handles custom tier names")
func customTierNames() {
    var tiers: Items = ["Gold": [], "Silver": [], "Bronze": [], "unranked": []]
    let item = Item(id: "1", attributes: ["name": "Test"])
    tiers["unranked"]?.append(item)

    let moved = TierLogic.moveItem(tiers, itemId: "1", targetTierName: "Gold")

    #expect(moved["Gold"]?.count == 1)
    #expect(moved["unranked"]?.isEmpty == true)
}

@Test("HeadToHead distributes to custom tier order")
func customTierDistribution() {
    let pool: [Item] = (1...30).map { Item(id: "\($0)", attributes: ["name": "Item \($0)"]) }
    let tierOrder = ["Best", "Good", "Okay", "Bad"]

    let result = HeadToHeadLogic.quickTierPass(
        from: pool,
        records: [:],
        tierOrder: tierOrder,
        baseTiers: [:]
    )

    #expect(Set(result.tiers.keys).intersection(Set(tierOrder)) == Set(tierOrder))
}
```

### Integration Tests

**Test Scenarios**:

1. **3-Tier System** ("Gold", "Silver", "Bronze")
   - Initialize state
   - Add items
   - Run H2H
   - Export to JSON/CSV
   - Import back
   - Apply theme
   - Verify analysis

2. **10-Tier System** (S,S+,A,A+,B,B+,C,C+,D,F)
   - Same workflow as above

3. **Custom Names** ("Totally Awesome", "Pretty Good", "Meh", "Trash")
   - Verify labels render correctly
   - Verify export uses labels
   - Verify toolbar shows labels

4. **Custom Ordering** (F,D,C,B,A,S - reverse order)
   - Verify grid renders in reverse
   - Verify H2H distributes correctly (best items to F)
   - Verify export order matches

### UI Tests

**Test File**: `TiercadeUITests/CustomTierUITests.swift`

```swift
func testToolbarShowsCustomTiers() throws {
    app.launchArguments = ["-uiTest", "-customTiers", "Gold,Silver,Bronze"]
    app.launch()

    // Open clear tier menu
    app.buttons["Toolbar_ClearMenu"].tap()

    // Verify custom tiers appear
    XCTAssertTrue(app.buttons["Clear Gold Tier"].exists)
    XCTAssertTrue(app.buttons["Clear Silver Tier"].exists)
    XCTAssertTrue(app.buttons["Clear Bronze Tier"].exists)

    // Verify SABCDF don't appear
    XCTAssertFalse(app.buttons["Clear S Tier"].exists)
}
```

---

## Migration Path & Backward Compatibility

### Backward Compatibility Guarantees

1. **Default Behavior Unchanged**: All existing tier lists continue to use SABCDF
2. **Persistence Format**: UserDefaults/SwiftData already store `tierOrder`, `tierLabels`, `tierColors`
3. **Import/Export**: Existing JSON/CSV files import correctly (SABCDF tiers)
4. **TierIdentifier Enum**: Remains available for type-safe APIs, but not enforced

### Migration for Existing Tier Lists

**No migration needed** - state already contains required properties:
- `tierOrder`: Already persisted
- `tierLabels`: Already persisted
- `tierColors`: Already persisted

After fixes, existing tier lists will:
- Continue rendering correctly (grid already uses `tierOrder`)
- Export with correct tier names (once export fix applied)
- Support theme changes (once theme fix applied)

### Opt-In Custom Tiers

Users access custom tiers via **Tier List Creator/Wizard**:

1. User taps "New Tier List"
2. Wizard shows "Custom Tiers" option
3. User adds/removes/reorders/renames tiers
4. Wizard commits to `tierOrder`, `tierLabels`, `tierColors`
5. All other systems pick up changes automatically

**No code changes needed** - wizard already supports this, just not connected end-to-end due to export/import/UI bugs.

---

## Risk Assessment & Mitigation

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Export breaks for existing tier lists | Low | High | Add tests for SABCDF export before changes |
| Theme colors don't map to custom tiers | Medium | Medium | Implement fallback color logic |
| Import CSV with unknown tier names | Medium | Low | Add validation/warning before import |
| Performance with 20+ tiers | Low | Low | Test with large tier counts |

### Rollback Plan

All changes are **non-breaking internal refactors**:
- State initialization: Falls back to SABCDF default
- Export: If `tierOrder` empty, use SABCDF fallback
- UI: If `tierOrder` empty, use SABCDF fallback

**Safe to deploy incrementally** via feature flag if needed.

---

## Success Criteria

### Phase 1-4 (Critical)
- [ ] Initialize tier list with custom tier order
- [ ] Export preserves custom tier names in all formats
- [ ] Import handles custom tier names
- [ ] Toolbar menus show custom tier labels
- [ ] All existing tier lists continue working

### Phase 5-6 (Medium)
- [ ] Custom tier colors render correctly
- [ ] Themes apply to variable-length tier lists
- [ ] Fallback colors work for unknown tiers

### Phase 7 (Nice to Have)
- [ ] Analysis statistics show custom tier labels
- [ ] TierIdentifier enum marked as deprecated in favor of string-based APIs

---

## Recommended Next Steps

1. **Review this plan** with stakeholders
2. **Create feature branch**: `feature/flexible-tier-system`
3. **Implement Phase 1** (state initialization) with tests
4. **Validate** with 3-tier and 10-tier scenarios
5. **Implement Phases 2-4** (export/import/UI) sequentially
6. **Run comprehensive test suite** (unit + integration + UI)
7. **Deploy behind feature flag** for beta testing
8. **Document** custom tier creation workflow for users

**Estimated Effort**: 3-5 days (1 day per phase + testing)

---

## References

### Apple Documentation Consulted

1. **SwiftData Schema** - Dynamic model configuration approaches
2. **Swift Collections** - Dictionary iteration patterns
3. **Swift 6 Strict Concurrency** - Sendable conformance for tier structures

### Related Code Locations

- State: `TierListState.swift`, `AppState.swift`
- Core Logic: `TierLogic.swift`, `HeadToHeadLogic.swift` (already flexible ✅)
- Export: `AppState+Export.swift` (needs fixes ❌)
- Import: `AppState+Import.swift` (needs fixes ❌)
- UI: `ContentView+Toolbar.swift` (needs fixes ❌), `ContentView+TierGrid.swift` (already flexible ✅)
- Design: `DesignTokens.swift` (needs enhancement 🟡), `TierTheme.swift` (needs enhancement 🟡)

---

## Summary Impact Table

| Feature | Custom Names | Custom Order | Variable Count | Severity | Phase |
|---------|--------------|--------------|----------------|----------|-------|
| **TierListState initialization** | ❌ Hardcoded | ❌ Hardcoded | ⚠️ Manual | 🔴 HIGH | 1 |
| **Toolbar Clear Menu** | ❌ Hardcoded | ❌ Hardcoded | ❌ Hardcoded | 🔴 HIGH | 3 |
| **Export TierConfig** | ❌ Hardcoded | ❌ Hardcoded | ❌ Hardcoded | 🔴 HIGH | 2 |
| **CSV Import** | ❌ Hardcoded | ❌ Hardcoded | ⚠️ Ignored | 🔴 HIGH | 4 |
| **Design Tokens (Colors)** | ❌ Falls back gray | ✅ OK | ✅ OK | 🟡 MEDIUM | 5 |
| **Theme System** | ⚠️ Fallback to index | ⚠️ Index mismatch | ❌ 6 tiers only | 🟡 MEDIUM | 6 |
| **Analysis Stats** | ⚠️ IF tierOrder set | ✅ Dynamic | ❌ Excludes unlisted | 🟡 MEDIUM | 7 |
| **Tier Grid Rendering** | ✅ Dynamic | ✅ Dynamic | ✅ Dynamic | 🟢 LOW | - |
| **Head-to-Head** | ✅ Fully dynamic | ✅ Fully dynamic | ✅ Fully dynamic | 🟢 LOW | - |
| **TierLogic** | ✅ Fully dynamic | ✅ Fully dynamic | ✅ Fully dynamic | 🟢 LOW | - |
| **Wizard/Creator** | ✅ Fully dynamic | ✅ Fully dynamic | ✅ Fully dynamic | 🟢 LOW | - |

---

**Document Version**: 1.0
**Last Updated**: 2025-11-03
**Next Review**: After Phase 1 implementation
