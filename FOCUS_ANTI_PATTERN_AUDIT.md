# Focus Anti-Pattern Audit Report
**Date:** 2025-11-04
**Issue:** Manual focus trapping/reset patterns that fight against tvOS focus system

## Executive Summary

Audited the entire codebase for manual focus management anti-patterns. Found **3 files** with the anti-pattern that require remediation:

1. ✅ **QuickMoveOverlay.swift** - FIXED (already remediated)
2. ✅ **TierListBrowserScene.swift** - FIXED (already remediated)
3. ⚠️ **ThemeCreatorOverlay.swift** - NEEDS FIX (ZStack overlay with manual reset)
4. ✅ **HeadToHeadOverlay.swift** - FIXED (converted to modal with default focus + no manual resets)
5. ⚠️ **ThemeLibraryOverlay.swift** - NEEDS CLEANUP (obsolete workaround code remains)

## Anti-Pattern Definition

### The Manual Focus Reset Loop
```swift
// ❌ ANTI-PATTERN
@State private var lastFocus: SomeType?
@State private var suppressFocusReset = false

.onChange(of: focusedElement) { _, newValue in
    guard !suppressFocusReset else { return }
    if let newValue {
        lastFocus = newValue
    } else if let lastFocus {
        focusedElement = lastFocus  // ❌ Fighting the system
    }
}
```

**Why it's bad:**
- Fights against natural focus navigation
- Doesn't actually contain focus (focus can still escape via hardware navigation)
- Creates brittle state management with suppressFocusReset flags
- Goes against Apple's guidance: "Focus should almost always be under user control"

### The Correct Pattern
```swift
// ✅ CORRECT: Use modal presentation for focus containment
.fullScreenCover(isPresented: $showOverlay) {
    MyOverlay()
    // Automatic focus containment via separate presentation context
}
```

## Detailed Findings

### 1. ThemeCreatorOverlay.swift ⚠️ PRIORITY FIX

**Status:** ZStack overlay with manual focus reset anti-pattern
**Location:** Lines 21-22 (state), 74-83 (setup), 100-107 (anti-pattern)
**Presentation:** ZStack in MainAppView.swift:250-256

**Anti-Pattern Code:**
```swift
@State private var lastFocus: FocusField?
@State private var suppressFocusReset = false

.onChange(of: focusedElement) { _, newValue in
    guard !suppressFocusReset else { return }
    if let newValue {
        lastFocus = newValue
    } else if let lastFocus {
        focusedElement = lastFocus  // ❌ Manual reset
    }
}
```

**Also Has:** Custom directional navigation (lines 467-623) which is LEGITIMATE - handles arrow key navigation within the palette grid.

**Remediation Required:**
1. Convert to `.fullScreenCover()` (tvOS/iOS) and `.sheet()` (macOS) presentation
2. Remove manual focus reset code (lines 100-107)
3. Remove state variables `lastFocus` and `suppressFocusReset` (lines 21-22)
4. Remove setup/teardown logic (lines 74-83)
5. Keep custom directional navigation handlers (legitimate grid navigation)

---

### 2. HeadToHeadOverlay.swift ✅ RESOLVED

The HeadToHead overlay now uses modal presentation with default focus anchors, no longer reasserts focus manually, and routes directional input through structured helpers. The custom `applyFocusModifiers` callback was renamed and stripped of the exit/return reset loop.

Key changes:
1. Rebuilt UI with a progress rail, metric tiles, and clearer action bar naming.
2. Added HeadToHead-specific view modifiers (`headToHeadOverlayChrome`, `trackHeadToHeadPairs`, `headToHeadTVModifiers`).
3. Removed the `overlayHasFocus` reassert hack on macOS/iOS and rely on `@FocusState` default routing.

No further action needed for this overlay.

---

### 3. ThemeLibraryOverlay.swift ⚠️ CLEANUP NEEDED

**Status:** Already converted to `.fullScreenCover()` but obsolete workaround remains
**Location:** Lines 76-84 (obsolete workaround)
**Presentation:** `.fullScreenCover()` in MainAppView.swift (CORRECT)

**Obsolete Workaround Code:**
```swift
.onChange(of: overlayHasFocus) { _, newValue in
    guard !newValue, appState.overlays.showThemePicker else { return }
    Task { @MainActor in
        try? await Task.sleep(for: FocusWorkarounds.reassertDelay)
        if appState.overlays.showThemePicker {
            overlayHasFocus = true  // ❌ Workaround (now obsolete)
        }
    }
}
```

**Also Has:** Custom directional navigation (lines 238-268) which is LEGITIMATE - handles arrow key navigation within the theme grid.

**Remediation Required:**
1. Remove `.onChange(of: overlayHasFocus)` handler (lines 76-84)
2. Simplify `.onDisappear` to just reset focus state (lines 36-40)
3. Keep custom directional navigation handlers (legitimate grid navigation)

---

## Files Checked - No Issues Found ✅

### ContentView+TierRow.swift ✅
**Has:** `handleMoveCommand` function (lines 214-235)
**Status:** LEGITIMATE - Implements custom item reordering with left/right arrows in custom sort mode
**No Action Required**

### ThemeLibraryOverlay.swift (directional nav) ✅
**Has:** `handleMoveCommand` and `handleDirectionalInput` (lines 238-268)
**Status:** LEGITIMATE - Implements custom grid navigation for 2-column theme grid
**No Action Required**

### ThemeCreatorOverlay.swift (directional nav) ✅
**Has:** `handleMoveCommand` and directional handlers (lines 467-623)
**Status:** LEGITIMATE - Implements custom navigation within palette grid and form fields
**No Action Required**

---

## Key Distinction: Anti-Pattern vs Legitimate Custom Navigation

### ❌ Anti-Pattern: Manual Focus TRAPPING
Attempts to prevent focus from leaving by resetting it when it becomes nil:
```swift
.onChange(of: focus) { _, newValue in
    if newValue == nil { focus = lastFocus }  // ❌ Fighting system
}
```

### ✅ Legitimate: Custom Focus ROUTING
Handles arrow keys to navigate within complex layouts (grids, forms):
```swift
func handleMoveCommand(_ direction: MoveCommandDirection) {
    switch direction {
    case .left: focusAdjacentItem(offset: -1)   // ✅ Custom navigation
    case .right: focusAdjacentItem(offset: +1)  // ✅ Custom navigation
    // ...
    }
}
```

**The difference:** Custom routing GUIDES focus movement between items, while manual trapping PREVENTS focus from leaving. Only modal presentations can truly contain focus.

---

## Remediation Priority

1. **HIGH:** ThemeCreatorOverlay.swift - Convert to modal presentation
2. **MEDIUM:** HeadToHeadOverlay.swift - Remove obsolete anti-pattern code
3. **MEDIUM:** ThemeLibraryOverlay.swift - Remove obsolete workaround code

---

## Testing Checklist

After remediation, verify on tvOS simulator (Apple TV 4K 3rd gen, tvOS 26):

- [ ] ThemeCreatorOverlay properly traps focus (can't escape to background)
- [ ] Theme palette grid navigation works correctly with arrow keys
- [ ] Tier list navigation works correctly
- [ ] Save/Cancel buttons are accessible
- [ ] Exit command (Menu button) dismisses overlay
- [x] HeadToHeadOverlay still contains focus properly
- [x] HeadToHeadOverlay directional navigation works (if any remains)
- [ ] ThemeLibraryOverlay still contains focus properly
- [ ] ThemeLibraryOverlay grid navigation works correctly

---

## Apple Documentation References

- WWDC 2021: "Direct and reflect focus in SwiftUI" - FocusState patterns
- WWDC 2023: "The SwiftUI cookbook for focus" - Modal presentations, focus sections
- UIKit: "About focus interactions for Apple TV" - Focus philosophy
- SwiftUI: `.fullScreenCover()` and `.sheet()` API docs - Presentation contexts

---

## Related Commits

- Initial fix: QuickMoveOverlay and TierListBrowserScene anti-pattern removal
- Previous fix: ThemePicker, HeadToHead, Analytics, TierListBrowser modal conversion
