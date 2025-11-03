# SwiftLint Remediation Progress & Plan

**Branch:** `swiftlint`
**Date:** 2025-11-03
**Starting Violations:** 1,585
**Current Violations:** 1,574 (11 fixed, 0.7% reduction)

---

## ✅ Completed Work

### Phase 1: Auto-Fixes (11 violations fixed)
**Commit:** `d500619` - style(lint): apply SwiftLint auto-fixes

**Fixed:**
- ✅ Removed redundant `= nil` from optional property initializations (3 fixes)
- ✅ Simplified control statements (removed unnecessary parentheses) (1 fix)
- ✅ Replaced unused closure parameters with `_` (2 fixes)
- ✅ Fixed trailing newlines and whitespace (5 fixes)

**Result:** 1,585 → 1,574 violations

### Phase 2: ACL Automation (FAILED - Reverted)
**Commits:** `2f4a008` (broken), `3c97c57` (revert)

**Attempted:** Automated addition of `internal` keywords to 1,382+ declarations

**Failure Reason:** Python script incorrectly added `internal` to:
- Local variables inside function bodies (Swift error: "can only be used in non-local scope")
- Switch case statements
- Nested closures

**Build Errors:** 150+ compilation failures in TiercadeCore

**Lesson Learned:** ACL violations require domain expertise to understand intended API surface. Automation is too risky without sophisticated AST parsing.

**Status:** Reverted all changes, deferred to manual review

---

## 📊 Current Violation Breakdown

| Priority | Category | Count | % of Total | Effort | Risk | Status |
|----------|----------|-------|-----------|--------|------|--------|
| **DEFER** | explicit_acl | 1,433 | 91% | Very High | High | Deferred |
| **DEFER** | explicit_top_level_acl | 40 | 3% | High | High | Deferred |
| **HIGH** | file_length | 8 | <1% | Medium | Low | Pending |
| **HIGH** | type_body_length | 5 | <1% | Medium | Low | Pending |
| **MEDIUM** | line_length | 48 | 3% | Low | Low | Pending |
| **MEDIUM** | cyclomatic_complexity | 3 | <1% | Medium | Low | Pending |
| **MEDIUM** | nesting | 16 | 1% | Medium | Low | Pending |
| **LOW** | function_body_length | 8 | <1% | Low | Low | Pending |
| **LOW** | Other style issues | 13 | <1% | Low | Low | Pending |

---

## 🎯 Recommended Next Steps

### Option A: Complete High-Value Tasks (Recommended)
**Est. Time:** 3-4 hours
**Value:** High (improves maintainability, enforces playbook requirements)
**Risk:** Low (structural changes, well-tested patterns)

#### Phase 3: Split Oversized Files (8 violations)

**Files to Split:**

1. **ContentView+Toolbar.swift** (787 lines → target <600)
   - Keep `ToolbarView` (497 lines) in main file
   - Extract `TiersDocument` → `ContentView+Toolbar+FileDocument.swift` (21 lines)
   - Extract `SecondaryToolbarActions` → `ContentView+Toolbar+SecondaryActions.swift` (84 lines)
   - Extract `BottomToolbarSheets` → `ContentView+Toolbar+BottomSheets.swift` (121 lines)
   - Extract `MacAndTVToolbarSheets` → `ContentView+Toolbar+PlatformSheets.swift` (55 lines)

2. **AIChatOverlay.swift** (676 lines → target <600)
   - Already has helper files (`+ImagePreview.swift`, `+ImageGeneration.swift`, `+Tests.swift`)
   - Extract message rendering logic → `AIChatOverlay+Messages.swift` (~100 lines)
   - Extract UI components → `AIChatOverlay+Components.swift` (~80 lines)

3. **ContentView+TierGrid.swift** (668 lines → target <600)
   - Already has `ContentView+TierGrid+HardwareFocus.swift`
   - Extract drop handling → `ContentView+TierGrid+DropHandling.swift` (~80 lines)

4. **HeadToHead+Internals.swift** (611 lines → target <600)
   - Extract statistical helpers → `HeadToHead+Statistics.swift` (~50 lines)

**Validation:** After each split, run:
```bash
./build_install_launch.sh        # tvOS
./build_install_launch.sh macos  # macOS
```

#### Phase 4: Fix Code Quality Issues (67 violations)

**Line Length (48 violations):** Break long lines at logical points
```bash
swiftlint lint --strict 2>&1 | grep "line_length" > line_length_violations.txt
# Fix each violation by breaking at operators, commas, or closures
```

**Cyclomatic Complexity (3 violations):** Extract complex branches into helper methods
```bash
swiftlint lint --strict 2>&1 | grep "cyclomatic_complexity"
```

**Nesting (16 violations):** Use early returns and guard statements
```bash
swiftlint lint --strict 2>&1 | grep "nesting"
```

#### Phase 5: Fix Low-Hanging Style Issues (13 violations)

- `vertical_parameter_alignment`: 4 violations (align parameters in multi-line function declarations)
- `large_tuple`: 3 violations (replace with structs)
- `multiple_closures_with_trailing_closure`: 2 violations (use explicit closures)
- `for_where`: 2 violations (combine `for` and `if` into `for-where`)
- `type_name`: 1 violation (rename to follow conventions)
- `force_try`: 1 violation in `PathTraversalTests.swift:78` (replace with proper error handling)

---

### Option B: Defer to Future PR
**Recommendation:** Address ACL violations separately with domain expert review

**Rationale:**
1. **Complexity:** 1,473 violations require understanding intended API surface
2. **Risk:** Wrong visibility can expose internal APIs or break external consumers
3. **Expertise:** Needs Swift 6 module system knowledge + project architecture understanding

**Action Plan:**
1. Create GitHub issue documenting ACL violations
2. Include this document as reference
3. Tag maintainer/architect for API review
4. Schedule dedicated session (est. 8-12 hours)

---

## 🚀 Execution Guide

### Step-by-Step: File Splitting

**Example: ContentView+Toolbar.swift**

1. **Read full file:**
   ```bash
   head -506 Tiercade/Views/Toolbar/ContentView+Toolbar.swift > /tmp/main.swift
   ```

2. **Extract sections:**
   ```bash
   # Lines 507-526 → FileDocument
   sed -n '1,7p' Tiercade/Views/Toolbar/ContentView+Toolbar.swift > Tiercade/Views/Toolbar/ContentView+Toolbar+FileDocument.swift
   sed -n '507,526p' Tiercade/Views/Toolbar/ContentView+Toolbar.swift >> Tiercade/Views/Toolbar/ContentView+Toolbar+FileDocument.swift

   # Repeat for other sections...
   ```

3. **Update main file:**
   ```bash
   # Keep header + ToolbarView (lines 1-506)
   sed -n '1,506p' Tiercade/Views/Toolbar/ContentView+Toolbar.swift > /tmp/toolbar_main.swift
   mv /tmp/toolbar_main.swift Tiercade/Views/Toolbar/ContentView+Toolbar.swift
   ```

4. **Validate:**
   ```bash
   swiftlint lint Tiercade/Views/Toolbar/ContentView+Toolbar*.swift
   ./build_install_launch.sh macos
   ./build_install_launch.sh  # tvOS
   ```

5. **Commit:**
   ```bash
   git add Tiercade/Views/Toolbar/ContentView+Toolbar*.swift
   git commit -m "refactor(lint): split ContentView+Toolbar into smaller files

   Extracted helper structs to separate files following project pattern:
   - ContentView+Toolbar+FileDocument.swift (TiersDocument)
   - ContentView+Toolbar+SecondaryActions.swift (SecondaryToolbarActions)
   - ContentView+Toolbar+BottomSheets.swift (BottomToolbarSheets)
   - ContentView+Toolbar+PlatformSheets.swift (MacAndTVToolbarSheets)

   Main file: 787 → 497 lines
   file_length violations: 8 → 7

   Validated: Both tvOS and macOS builds succeed

   🤖 Generated with Claude Code"
   ```

---

## 📝 Testing Checklist

After completing splits:

- [ ] Run SwiftLint: `swiftlint lint --strict | tee swiftlint_after.txt`
- [ ] Build tvOS: `./build_install_launch.sh`
- [ ] Build macOS: `./build_install_launch.sh macos`
- [ ] Run tests: `cd TiercadeCore && swift test`
- [ ] Compare violations: `diff swiftlint_before.txt swiftlint_after.txt`

---

## 🎓 Lessons Learned

### What Worked
- ✅ `swiftlint --fix` for trivial style issues
- ✅ File splitting follows clear patterns (existing `+HardwareFocus` example)
- ✅ Incremental approach with frequent validation

### What Didn't Work
- ❌ Automated ACL addition (too complex for regex/simple scripts)
- ❌ Batch operations without understanding Swift scoping rules
- ❌ Attempting to fix all 1,585 violations at once

### Best Practices
1. **Always validate builds after structural changes** (both tvOS and macOS)
2. **Use DerivedData cleanup** when facing stale compiler errors
3. **Commit frequently** with descriptive messages
4. **Defer complex issues** that require domain expertise

---

## 📚 References

- **Project Playbook:** `/Users/Shared/git/Tiercade/CLAUDE.md`
  - File size targets: 400/600 lines
  - Splitting patterns: See commits 7f9fb84, 373d731, f662d34
- **SwiftLint Config:** `.swiftlint.yml`
- **Existing Splits:**
  - `ContentView+TierGrid+HardwareFocus.swift`
  - `AIChatOverlay+ImagePreview.swift`
  - `MatchupArenaOverlay+HelperViews.swift`

---

## 🏁 Success Criteria

**Minimum (Completed):**
- ✅ 11 violations fixed
- ✅ No build regressions
- ✅ Clear documentation for future work

**Target (Option A):**
- 🎯 File length violations: 8 → 0 (100% reduction)
- 🎯 Type body length violations: 5 → 0 (100% reduction)
- 🎯 Line length violations: 48 → 0 (100% reduction)
- 🎯 Complexity/nesting violations: 19 → 0 (100% reduction)
- 🎯 Style issues: 13 → 0 (100% reduction)
- **Total Impact:** 1,574 → 1,483 violations (91 fixed, 5.8% reduction)
- **ACL Deferred:** 1,473 violations (~94% of remaining)

**Stretch (Option A + B):**
- All 1,574 violations resolved
- Full SwiftLint compliance
- Clean `swiftlint lint --strict` output

---

## ⏱️ Time Estimates

| Task | Estimated Time | Risk |
|------|---------------|------|
| Split 4 files | 1.5-2 hours | Low |
| Fix line length (48) | 0.5 hour | Low |
| Fix complexity (3) | 0.5-1 hour | Medium |
| Fix nesting (16) | 0.5-1 hour | Medium |
| Fix style issues (13) | 0.5 hour | Low |
| **Total (Option A)** | **3-5 hours** | **Low-Medium** |
| ACL review (Option B) | 8-12 hours | High |

---

**Next Action:** Choose Option A or B and proceed with execution guide above.
