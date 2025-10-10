# Tier Creator Focus & Navigation Audit
**Date:** October 9, 2025
**Target:** tvOS 26+ with Swift 6 strict concurrency
**Reference:** WWDC 2024 "Migrate your TVML app to SwiftUI" and Apple SwiftUI documentation

---

## Executive Summary

The Tier Creator implementation exhibits **significant focus management issues** that violate Apple's tvOS design principles and create a poor user experience. The primary problems are:

1. **Over-engineering with manual focus management** instead of using system-level defaults
2. **Excessive and incorrect use of `.focusSection()`** creating focus traps
3. **Missing proper button styles** for tvOS interactions
4. **Redundant focus state management** competing with SwiftUI's built-in system
5. **UI overlap issues** from improper layout containment
6. **Custom focus utilities** that fight against SwiftUI's focus engine

---

## Critical Issues Found

### 1. **Excessive `.focusSection()` Usage** ⚠️ SEVERE

**Problem:** Nearly every major container in Tier Creator has `.focusSection()` applied, creating isolated focus regions that prevent natural navigation.

**Locations:**
- `TierCreatorView.swift`: Header toolbar, footer actions, and stage content ALL have separate focus sections
- `TierCreatorSetupStageView.swift`: Both `detailCard` and `sidebar` are separate focus sections
- `TierCreatorItemsStageView.swift`: `library` and `inspector` are separate focus sections
- `TierCreatorStructureStageView.swift`: Three separate focus sections for rail, preview, and inspector

**Apple Guidance (from `focusSection()` docs):**
> "Use focus sections to customize SwiftUI's behavior when the user moves focus between views."
>
> Focus sections should be used **sparingly** to guide focus to distant UI regions. The example shows ONE sidebar getting focus from buttons on the opposite side of the screen.

**Current Implementation:**
```swift
// TierCreatorView.swift - PROBLEM: Too many focus sections
TierCreatorHeaderToolbar(...)
    .focusSection()  // ❌ Header isolated

stageContent(for: project)
    .focusScope(focusNamespace)  // ❌ Content isolated

TierCreatorFooterActions(...)
    .focusSection()  // ❌ Footer isolated
```

**What Happens:**
- Users get "stuck" in sections and can't navigate naturally with the remote
- Swiping right/left/up/down doesn't move focus where expected
- Creates invisible walls between UI regions
- Breaks the natural flow that tvOS users expect

**Correct Pattern:**
Focus sections should only be used for:
1. Sidebars that need to receive focus from distant buttons
2. Modal overlays that need focus containment
3. Special cases where default behavior fails

### 2. **Missing `.buttonStyle()` Modifiers** ⚠️ SEVERE

**Problem:** Custom buttons throughout Tier Creator don't use appropriate tvOS button styles, breaking focus affordances.

**WWDC 2024 Guidance:**
> "By default, buttons on tvOS use the bordered buttonStyle... To achieve the appearance we want, we'll use the borderless buttonStyle."
>
> "The card buttonStyle provides a rounded platter to back your content, which lifts and moves in a more subtle manner"

**Current Implementation:**
```swift
// TierCreatorItemCard - PROBLEM: Manual styling without proper button style
Button(action: onSelect) {
    VStack(alignment: .leading, spacing: Metrics.grid) {
        // ... content
    }
    .padding(...)
    .frame(maxWidth: .infinity, alignment: .leading)
}
.buttonStyle(.tvGlass)  // ✅ HAS button style
.focusable(true)  // ❌ REDUNDANT - buttons are already focusable!
.background(
    RoundedRectangle(...)
        .fill(isSelected ? Palette.brand.opacity(0.22) : ...)  // ❌ Manual selection
)
```

**Problems:**
1. `.focusable(true)` on buttons is redundant - buttons are inherently focusable
2. Manual selection state (isSelected) fights with focus state
3. Custom `.tvGlass` style may not provide proper tvOS focus effects

**Apple Pattern:**
```swift
// From WWDC 2024 example
Button {} label: {
    Image(...)
        .resizable()
        .aspectRatio(...)
    Text(title)
}
.buttonStyle(.borderless)  // System handles ALL focus effects
```

### 3. **Manual Focus State Management** ⚠️ MODERATE

**Problem:** Custom focus utilities and manual resetFocus calls compete with SwiftUI's focus engine.

**Code:**
```swift
// TierCreatorView.swift
@Environment(\.resetFocus) private var resetFocus

.onAppear {
    refreshStageIssues(for: project)
    resetFocus(in: focusNamespace)  // ❌ Manual focus reset
}
.onChange(of: appState.tierCreatorStage) { _, _ in
    refreshStageIssues(for: project)
    resetFocus(in: focusNamespace)  // ❌ Manual focus reset
}
```

**Problems:**
1. `resetFocus` environment value is custom, not SwiftUI standard
2. Manual focus management on stage changes prevents natural focus memory
3. Fighting against tvOS's built-in focus restoration

**Apple Pattern:**
Use `prefersDefaultFocus` ONLY when needed, let system handle the rest:
```swift
.prefersDefaultFocus(in: namespace)  // Only on ONE element per scope
```

### 4. **Incorrect `focusScope` Usage** ⚠️ MODERATE

**Problem:** `focusScope(focusNamespace)` is applied to stage content, but combined with excessive `focusSection()` calls negates its purpose.

**Apple Documentation:**
> "Creates a focus scope that SwiftUI uses to limit default focus preferences."
>
> "Pass this namespace to `prefersDefaultFocus(_:in:)` and the `resetFocus` function."

**Current Implementation:**
```swift
stageContent(for: project)
    .focusScope(focusNamespace)  // Scope defined
    .padding(.horizontal, Metrics.grid * 3)

// But inside each stage:
TierCreatorSetupStageView(...) {
    detailCard.focusSection()  // ❌ Breaks the scope!
    sidebar.focusSection()     // ❌ Breaks the scope!
}
```

**What Should Happen:**
- Define ONE `focusScope` for the stage container
- Use `prefersDefaultFocus(in: namespace)` on the FIRST focusable element
- Remove all internal `focusSection()` calls unless absolutely necessary

### 5. **Custom Field Focus Pattern** ⚠️ MODERATE

**Problem:** `TierCreatorSetupField` has custom focus handling that's overly complex.

**Code:**
```swift
// TierCreatorSetupStageView.swift
private extension View {
    @ViewBuilder
    func tierCreatorDefaultFocus(_ prefers: Bool, in namespace: Namespace.ID?) -> some View {
        if prefers, let namespace {
            prefersDefaultFocus(in: namespace)
        } else {
            self
        }
    }
}
```

**Issues:**
1. Custom wrapper around standard API adds complexity
2. Conditional logic makes focus behavior unpredictable
3. Not needed - use `prefersDefaultFocus` directly

**Correct Pattern:**
```swift
TextField("Title", text: $title)
    .prefersDefaultFocus(in: namespace)  // Direct and clear
```

### 6. **Layout Overlap & Z-Index Issues** ⚠️ MODERATE

**Problem:** No evidence of proper focus-driven layout from code review, likely causing overlaps mentioned in user report.

**Missing Patterns:**
The WWDC talk emphasizes that focused elements should automatically move text and other UI out of the way:
> "when focused this lifts and tilts... and any nearby text slides to avoid being occluded by the raised image"

**Current Implementation:**
- Fixed padding and margins throughout
- No `.offset` modifiers based on focus state
- No `@FocusState` properties in individual cards to detect focus

**Required Pattern:**
```swift
@FocusState private var isFocused: Bool

SomeView()
    .focusable()
    .focused($isFocused)
    .offset(y: isFocused ? -20 : 0)  // Move when focused
    .animation(.default, value: isFocused)
```

### 7. **Inspector Panels Have Focus Sections** ⚠️ MINOR

**Problem:** `TierCreatorItemInspector` and `TierCreatorTierInspector` are marked as focus sections when they should be natural children.

**Code:**
```swift
// TierCreatorItemLibrary.swift
TierCreatorItemInspector(...)
    .focusSection()  // ❌ Unnecessary isolation
```

**Why It's Wrong:**
- Inspectors contain form fields that should be naturally focusable
- Creating a focus section forces explicit navigation to them
- tvOS users expect to swipe naturally between library and inspector

---

## Anti-Patterns vs. Apple Best Practices

| Current Tier Creator Pattern | Apple's Recommended Pattern | Impact |
|------------------------------|----------------------------|--------|
| `.focusSection()` on every major container | Use sparingly for distant UI regions | Breaks natural navigation |
| Manual `resetFocus` calls | Let system restore focus automatically | Disrupts user expectations |
| `.focusable(true)` on buttons | Remove - buttons are inherently focusable | Redundant, may cause conflicts |
| Custom `tierCreatorDefaultFocus` wrapper | Use `prefersDefaultFocus` directly | Unnecessary complexity |
| Multiple focus sections in one screen | ONE `focusScope` with ONE default focus | Users get trapped |
| Manual selection state tracking | Let button focus state handle it | Fighting the system |
| `.tvGlass` custom button style | Use `.borderless` or `.card` | May lack proper focus effects |

---

## Recommended Architecture Changes

### Phase 1: Remove Over-Engineering (High Priority)

1. **Remove ALL `.focusSection()` calls** except:
   - Header toolbar (only if needed to trap focus from content)
   - Footer actions (only if needed to trap focus from content)
   - MAYBE keep on modal overlays if shown

2. **Remove redundant `.focusable(true)` calls** on:
   - All buttons (they're already focusable)
   - Text fields (already focusable)
   - Any view with a button style

3. **Simplify to ONE focus scope per stage:**
```swift
// TierCreatorView.swift
stageContent(for: project)
    .focusScope(focusNamespace)  // ✅ Keep this
    // Remove all internal focusSection() calls

// Inside each stage view:
// Just mark the FIRST element as default focus
TextField("Title", text: $title)
    .prefersDefaultFocus(in: focusNamespace)
```

### Phase 2: Use Proper Button Styles (High Priority)

Replace custom styling with Apple's standard button styles:

```swift
// Item cards
Button(action: onSelect) {
    VStack(alignment: .leading) {
        Text(item.title)
        Text(item.subtitle)
    }
}
.buttonStyle(.borderless)  // ✅ System handles focus, lift, tilt
// Remove .focusable(true)
// Remove manual .background() selection state
```

### Phase 3: Fix Layout System (Medium Priority)

Add proper focus-driven layout adjustments:

```swift
@FocusState private var focusedItemId: String?

ForEach(items) { item in
    ItemCard(item: item)
        .focused($focusedItemId, equals: item.id)
        .scaleEffect(focusedItemId == item.id ? 1.05 : 1.0)
        .zIndex(focusedItemId == item.id ? 1 : 0)
}
```

### Phase 4: Simplify Focus Management (Medium Priority)

1. **Remove custom `resetFocus` calls** - let tvOS handle focus restoration
2. **Remove `tierCreatorDefaultFocus` wrapper** - use standard API
3. **Trust the system** - SwiftUI's focus engine is sophisticated

### Phase 5: Proper Button Style Usage (Low Priority)

Audit all `.tvGlass` usage and consider replacing with standard styles:

```swift
// For content cards (library items)
.buttonStyle(.borderless)

// For toolbar buttons
.buttonStyle(.card)  // Or keep .tvGlass if it properly implements focus

// For action buttons
.buttonStyle(.bordered)  // Standard tvOS button
```

---

## Specific File Recommendations

### `TierCreatorView.swift`

**Remove:**
```swift
.focusSection()  // On header
.focusSection()  // On footer
```

**Keep:**
```swift
.focusScope(focusNamespace)  // On stage content
```

**Change:**
```swift
// Remove manual reset on stage change
.onChange(of: appState.tierCreatorStage) { _, _ in
    refreshStageIssues(for: project)
    // resetFocus(in: focusNamespace)  ❌ Remove this
}
```

### `TierCreatorSetupStageView.swift`

**Remove:**
```swift
.focusSection()  // On detailCard
.focusSection()  // On sidebar
```

**Simplify:**
```swift
// Remove custom wrapper
// private extension View {
//     func tierCreatorDefaultFocus(...) { ... }  ❌ Remove
// }

// Use standard API directly:
TextField("Title", text: $title)
    .prefersDefaultFocus(in: focusNamespace)
```

### `TierCreatorItemsStageView.swift`

**Remove:**
```swift
.focusSection()  // On library
.focusSection()  // On inspector
```

**Simplify:**
```swift
TierCreatorSearchField(...)
    .prefersDefaultFocus(in: focusNamespace)  // ✅ Keep - first element

// Remove redundant .focusable() on item cards
```

### `TierCreatorStructureStageView.swift`

**Remove:**
```swift
.focusSection()  // On rail
.focusSection()  // On preview
.focusSection()  // On inspector
```

**Fix button pattern:**
```swift
ForEach(tiers, id: \.tierId) { tier in
    TierRailRow(...)
        .prefersDefaultFocus(tier.tierId == tiers.first?.tierId, in: focusNamespace)
        // ✅ Only the first row gets default focus
}
```

### `TierCreatorItemCard.swift` / `TierRailRow.swift`

**Change:**
```swift
Button(action: onSelect) {
    VStack(alignment: .leading) {
        // ... content
    }
}
.buttonStyle(.borderless)  // ✅ Use standard style
// .focusable(true)  ❌ Remove - redundant
// .background(...)  ❌ Remove - let button style handle it
```

### `TierCreatorItemInspector.swift` / `TierCreatorTierInspector.swift`

**Remove:**
```swift
.focusSection()  // Remove from inspector wrapping
```

**Keep individual field focusability:**
```swift
TextField(prompt, text: text)
    .focusable(true)  // ✅ OK for explicit text entry
```

---

## Testing Recommendations

After implementing changes, test the following scenarios:

### Focus Navigation Tests

1. **Natural Flow:** Open Tier Creator → Press right/left/up/down on remote
   - **Expected:** Focus moves naturally between all elements without "sticking"
   - **Current:** Users get trapped in sections

2. **Stage Transitions:** Switch between Setup → Items → Structure
   - **Expected:** Focus lands on first logical element (uses `prefersDefaultFocus`)
   - **Current:** Manual `resetFocus` may cause unexpected focus

3. **Inspector Access:** Navigate from library to inspector
   - **Expected:** Smooth swipe right to inspector fields
   - **Current:** May be blocked by focus section

4. **Button Focus:** Focus on any button/card
   - **Expected:** Automatic lift, tilt, drop shadow, scale
   - **Current:** May lack proper effects if custom style doesn't implement them

5. **Toolbar Focus:** Navigate to header toolbar
   - **Expected:** Can reach from content with upward swipe
   - **Current:** May be isolated by focus section

### UI Overlap Tests

1. **Card Focus:** Focus on an item card
   - **Expected:** Card lifts without overlapping adjacent text
   - **Current:** Likely overlaps due to missing focus-driven layout

2. **Multi-Column Layout:** Navigate in items grid
   - **Expected:** Focused card has room to expand
   - **Current:** Fixed layout may cause clipping

---

## Implementation Priority

### 🔴 Critical (Do First)
1. Remove ALL unnecessary `.focusSection()` calls (except maybe header/footer)
2. Remove ALL redundant `.focusable(true)` on buttons
3. Replace custom button backgrounds with `.buttonStyle(.borderless)`

### 🟡 High (Do Soon)
4. Simplify to ONE `prefersDefaultFocus` per focus scope
5. Remove manual `resetFocus` calls - trust the system
6. Remove custom `tierCreatorDefaultFocus` wrapper

### 🟢 Medium (Do When Possible)
7. Add proper focus state tracking for layout adjustments
8. Test and fix UI overlaps with focus-driven offsets
9. Audit all `.tvGlass` usages vs. standard button styles

### ⚪ Low (Nice to Have)
10. Add focus debugging (hold Option in simulator to see focus)
11. Profile focus performance in large lists
12. Consider custom focus effects only where truly needed

---

## Code Smell Checklist

Use this checklist when reviewing any tvOS view:

- [ ] Does every container have `.focusSection()`? **→ BAD**
- [ ] Are buttons marked `.focusable(true)`? **→ REDUNDANT**
- [ ] Is there manual focus state tracking? **→ USUALLY UNNECESSARY**
- [ ] Are there custom focus wrappers? **→ SIMPLIFY**
- [ ] Multiple `@FocusState` properties? **→ PROBABLY TOO COMPLEX**
- [ ] Custom button selection state? **→ LET BUTTON STYLE HANDLE IT**
- [ ] Manual `resetFocus` calls? **→ TRUST THE SYSTEM**
- [ ] Fixed layouts without focus adjustments? **→ MAY CAUSE OVERLAP**

---

## References

1. **WWDC 2024 - "Migrate your TVML app to SwiftUI"**
   - Session 10207
   - Key Point: Use `.buttonStyle(.borderless)` and let system handle focus
   - Key Point: Focus sections are for distant UI regions, not every container

2. **Apple Documentation - `focusSection()`**
   - https://developer.apple.com/documentation/swiftui/view/focussection()
   - "Use focus sections to customize SwiftUI's behavior when the user moves focus between views"
   - Example shows ONE sidebar, not every container

3. **Apple Documentation - `focusScope(_:)`**
   - https://developer.apple.com/documentation/swiftui/view/focusscope(_:)
   - "Creates a focus scope that SwiftUI uses to limit default focus preferences"
   - Use with `prefersDefaultFocus` for one element

4. **Apple Documentation - `focusable(_:interactions:)`**
   - https://developer.apple.com/documentation/swiftui/view/focusable(_:interactions:)
   - "By default, SwiftUI enables all possible focus interactions"
   - Don't mark buttons as focusable - they already are

---

## Conclusion

The Tier Creator's focus management is **severely over-engineered**. The implementation attempts to manually control every aspect of focus, creating a system that:

1. ❌ Fights against tvOS's sophisticated focus engine
2. ❌ Traps users in isolated focus sections
3. ❌ Redundantly marks already-focusable elements
4. ❌ Manually manages state the system handles automatically
5. ❌ Uses custom patterns instead of Apple's proven APIs

**The fix is counter-intuitive but correct: REMOVE most of the focus management code.**

SwiftUI's tvOS focus system is designed to "just work" with minimal intervention. By removing the over-engineering and trusting the system, you'll achieve:

- ✅ Natural, expected navigation for tvOS users
- ✅ Proper focus effects (lift, tilt, shadow) automatically
- ✅ Simpler, more maintainable code
- ✅ Better performance (less state tracking)
- ✅ Alignment with Apple's design guidelines

**Next Step:** Begin Phase 1 (remove unnecessary focus sections) and test each change in the tvOS 26 simulator with a Siri Remote to verify natural navigation is restored.
