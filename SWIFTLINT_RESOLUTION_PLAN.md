# SwiftLint Resolution Plan

**Total Violations:** 1,627 (1,617 warnings, 10 errors)
**Files Affected:** 188

## Executive Summary

The majority of violations (90%+) are **explicit access control** issues where declarations lack explicit `internal`, `private`, `public`, or `fileprivate` keywords. The remaining violations span code organization (file/function length), formatting (line length), and complexity issues.

## Violation Breakdown by Rule

| Rule | Count | Severity | Priority |
|------|-------|----------|----------|
| `explicit_acl` | 1,469 | Warning | High |
| `line_length` | 57 | Warning | Medium |
| `explicit_top_level_acl` | 41 | Warning | High |
| `nesting` | 16 | Warning | Medium |
| `file_length` | 11 | Error/Warning | **Critical** |
| `function_body_length` | 10 | Error/Warning | **Critical** |
| `type_body_length` | 6 | Warning | Medium |
| `vertical_parameter_alignment` | 4 | Warning | Low |
| `large_tuple` | 3 | Warning | Low |
| `cyclomatic_complexity` | 2 | Warning | Medium |
| `force_cast` | 2 | Warning | High |
| `multiple_closures_with_trailing_closure` | 2 | Warning | Low |
| `trailing_whitespace` | 1 | Warning | Low |
| `vertical_whitespace` | 1 | Warning | Low |
| `for_where` | 1 | Warning | Low |
| `trailing_newline` | 1 | Warning | Low |

---

## Resolution Strategy

### Phase 1: Critical Errors (10 violations) - **MUST FIX**

#### 1.1 File Length Violations (11 files over 600 lines)

**Critical files requiring immediate splitting:**
- `MainAppView.swift` - 642 lines → Extract helper views/sections
- `ContentView+TierGrid.swift` - 693 lines → Already split into +HardwareFocus, continue extraction

**Strategy:**
- Extract helper views into separate files following existing pattern
- Move platform-specific logic behind `#if os(...)` guards
- Create focused extensions (e.g., `+Gestures.swift`, `+Layout.swift`)
- Target: <600 lines per file (ideally <400 for overlays per CLAUDE.md)

**⚠️ Critical constraints when splitting:**
- **Maintain tvOS-first patterns:** Preserve `.fullScreenCover()` for modals vs ZStack for transient overlays
- **Preserve focus management:** Do NOT reintroduce focus anti-patterns (manual reset loops, lastFocus caching)
- **Keep state mutations in AppState:** Never move state mutation logic out of `AppState+*.swift` extensions
- **Verify focus behavior:** After each split, perform tvOS simulator focus sweep with Siri Remote

#### 1.2 Function Body Length Violations (10 functions over 100 lines)

**Known error:**
- `MainAppView.swift:457` - Function spans 136 lines

**Strategy:**
- Break down into smaller, focused helper methods
- Extract view builders into separate computed properties
- Use composition over monolithic functions
- Target: <100 lines per function body
- **Prefer extracting pure view builders** over moving side-effect logic
- Keep any state mutation in AppState+*.swift extensions (never in views)

---

### Phase 2: High Priority Warnings

#### 2.1 Explicit Access Control (1,469 + 41 = 1,510 violations)

**Scope:** Nearly every file in the project

**Strategy:**
- **Default to `internal`** for most declarations (Swift's implicit default)
- Use `private` for implementation details not used outside the type
- Use `fileprivate` sparingly when needed across extensions in same file
- Use `public` only for API surface in TiercadeCore package
- Follow existing patterns in recently-modified files

**Automated approach:**
```bash
# For each file with violations:
# 1. Identify scope (view helpers, state properties, utility functions)
# 2. Apply appropriate access modifier
# 3. Verify build succeeds across all platforms
```

**Critical files by category:**

**TiercadeCore Package (~200 violations):**
- **⚠️ SPECIAL HANDLING REQUIRED** - This is a Swift Package, not app code
- **Rule:** Deliberately design public API surface
  - Mark types/methods intended for app consumption as `public`
  - Keep implementation details `internal` (not exported to app)
  - Use `private` for type-internal helpers
- **Process:** Manual review of each type to determine API intent
- **Do NOT mechanically mark everything `internal`** - this affects package API

**State management:**
- `AppState.swift` + all `AppState+*.swift` extensions
- `TierListState.swift`, `HeadToHeadState.swift`, `ThemeState.swift`
- **Rule:** Internal state properties, internal helper methods, private implementation details

**Views:**
- `MainAppView.swift`, `ContentView*.swift`
- All overlays (`Views/Overlays/*`)
- All components (`Views/Components/*`)
- **Rule:** Internal view structs, private helper methods, fileprivate when shared across extensions

**Design tokens:**
- `DesignTokens.swift`, `Palette.swift`, `TypeScale.swift`, etc.
- **Rule:** Internal for app-wide design tokens (accessed from Views module)

**Utilities:**
- All `Util/*` files
- **Rule:** Internal for reusable utilities, private for helpers

#### 2.2 Force Cast Violations (2 violations)

**Strategy:**
- Replace `as!` with safe `as?` + optional handling or `guard` statements
- **Map failures to typed errors** based on domain:
  - Import/Export code → `ImportError` / `ExportError`
  - Persistence code → `PersistenceError`
  - Analysis code → `AnalysisError` (future)
  - UI-only code → Assert in DEBUG, fail gracefully in release
- Add proper error handling for type conversions

---

### Phase 3: Medium Priority Warnings

#### 3.1 Line Length Violations (57 lines over 120 chars)

**Strategy:**
- Break long lines at logical points (parameter lists, chained methods, conditionals)
- Extract complex expressions into named variables
- Use multi-line parameter formatting for long function signatures

**Example transformations:**
```swift
// Before (>120 chars)
let result = someVeryLongFunctionName(parameter1: value1, parameter2: value2, parameter3: value3)

// After
let result = someVeryLongFunctionName(
    parameter1: value1,
    parameter2: value2,
    parameter3: value3
)
```

#### 3.2 Nesting Violations (16 violations)

**Strategy:**
- Extract nested closures into named functions
- Use guard statements for early returns
- Flatten conditional logic where possible

#### 3.3 Type Body Length Violations (6 violations)

**Strategy:**
- Split large types using extensions
- Group related functionality into focused extensions
- Follow existing `AppState+Feature.swift` pattern

#### 3.4 Cyclomatic Complexity (2 violations)

**Strategy:**
- Extract complex conditionals into helper methods
- Use switch statements instead of long if-else chains
- Break down complex functions into smaller units

---

### Phase 4: Low Priority Warnings

#### 4.1 Formatting Issues (8 violations total)
- `vertical_parameter_alignment` (4)
- `large_tuple` (3)
- `trailing_whitespace` (1)
- `vertical_whitespace` (1)
- `trailing_newline` (1)

**Strategy:** Quick formatting fixes, semi-automatable

#### 4.2 Style Improvements (3 violations)
- `for_where` (1) - Use `for x in y where condition` instead of nested if
- `multiple_closures_with_trailing_closure` (2) - Explicit closure parameters

---

## Execution Plan

### Step 1: Pre-flight checks
- [ ] Verify SwiftLint configuration (`.swiftlint.yml`)
- [ ] Capture baseline: `swiftlint lint > baseline.txt`
- [ ] Create feature branch: `swiftlint-cleanup`

### Step 2: Critical errors (must build on all platforms)
- [ ] **File length:** Split `MainAppView.swift` (642 → <600 lines)
  - [ ] After split: tvOS simulator focus sweep with Siri Remote
- [ ] **File length:** Split `ContentView+TierGrid.swift` (693 → <600 lines)
  - [ ] After split: tvOS simulator focus sweep with Siri Remote
- [ ] **Function length:** Refactor 136-line function in `MainAppView.swift`
- [ ] Verify build: `./build_install_launch.sh` (all platforms)

### Step 3: High priority - Access control
- [ ] **Phase 3a:** TiercadeCore package (~200 violations) - **MANUAL API DESIGN REVIEW**
  - [ ] Review each type's intended API surface
  - [ ] Mark public API as `public`, keep internals `internal`/`private`
- [ ] **Phase 3b:** State layer (`AppState*.swift`, `*State.swift`) - ~200 violations
- [ ] **Phase 3c:** View layer (`Views/**/*.swift`) - ~800 violations
- [ ] **Phase 3d:** Design/Util layers (`Design/*`, `Util/*`) - ~300 violations
- [ ] Verify build after each phase: `./build_install_launch.sh`

### Step 4: High priority - Force casts
- [ ] Identify and fix 2 `force_cast` violations
- [ ] Replace `as!` with safe unwrapping

### Step 5: Medium priority - Formatting & structure
- [ ] Fix 57 line length violations
- [ ] Fix 16 nesting violations
- [ ] Fix 6 type body length violations
- [ ] Fix 2 cyclomatic complexity violations

### Step 6: Low priority - Style polish
- [ ] Fix remaining 8 formatting violations
- [ ] Fix 3 style violations

### Step 7: Verification
- [ ] Run full SwiftLint: `swiftlint lint`
- [ ] Verify 0 errors, 0 warnings
- [ ] Build all platforms: `./build_install_launch.sh`
- [ ] Run TiercadeCore tests: `cd TiercadeCore && swift test`
- [ ] Manual smoke test on tvOS simulator

---

## Risk Mitigation

### Cross-platform build verification
**Critical:** After each major change (especially file splits and access control changes), verify ALL platforms build:
```bash
./build_install_launch.sh  # Builds tvOS, iOS, iPadOS, macOS
```

**Known risk patterns** (from CLAUDE.md):
- Visibility changes: `private` → `internal` required for cross-file extension access
- Platform-specific APIs: Must be gated with `#if os(...)`
- Example: Recent split [f662d34] caught macOS-specific visibility issues

### Incremental commits
- Commit after each phase to enable easy rollback
- Group related changes logically (e.g., "fix: explicit ACL for State layer")
- Run SwiftLint after each commit to track progress

### Testing checkpoints
- Full platform build after critical errors fixed
- **tvOS focus sweep** after each major view file split (MainAppView, ContentView+TierGrid)
- Full platform build after access control phase
- Full test suite before final commit

---

## Success Criteria

**Primary (Required):**
- [ ] **0 SwiftLint errors** (currently 10)
- [ ] All platforms build successfully (tvOS, iOS, iPadOS, macOS)
- [ ] TiercadeCore test suite passes
- [ ] No runtime regressions in manual testing
- [ ] tvOS focus behavior validated (no regressions from file splits)

**Secondary (Stretch):**
- [ ] **0 SwiftLint warnings** (currently 1,617)
  - Note: May defer ACL warnings if churn outweighs benefit
  - Can adjust `.swiftlint.yml` to target only top-level ACL if needed

---

## Estimated Effort

| Phase | Violations | Estimated Time |
|-------|-----------|----------------|
| Phase 1 (Critical) | 10 | 1-2 hours |
| Phase 2 (High Pri) | 1,512 | 3-4 hours |
| Phase 3 (Medium Pri) | 87 | 1-2 hours |
| Phase 4 (Low Pri) | 11 | 30 min |
| Verification | - | 30 min |
| **Total** | **1,627** | **6-9 hours** |

**Note:** Access control changes are high-volume but relatively mechanical. File/function splitting requires more careful consideration.

---

## Post-Cleanup Recommendations

1. **CI Integration:** Add SwiftLint to CI pipeline to prevent regression
2. **Pre-commit Hook:** Consider adding SwiftLint check before commits
3. **Documentation:** Update CLAUDE.md with access control guidelines
4. **Ongoing:** Maintain <400 line target for overlays, <600 for other files
