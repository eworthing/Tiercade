# SourceKit False Positives

## Summary
Most "No such module" errors shown in the Problems panel are **SourceKit indexing false positives**, not actual build errors. The project builds successfully via `xcodebuild`.

## Common False Positives
- ✅ `No such module 'TiercadeCore'` - **FALSE** - Module exists, build succeeds
- ✅ `No such module 'XCTest'` - **FALSE** - Test framework available in test targets
- ✅ `Cannot find 'Metrics' in scope` - **FALSE** - Defined in DesignTokens.swift, same target
- ✅ `Cannot find 'Palette' in scope` - **FALSE** - Defined in DesignTokens.swift, same target
- ✅ `Cannot find 'TypeScale' in scope` - **FALSE** - Defined in DesignTokens.swift, same target

## Real Errors Fixed
- ❌ **Duplicate files** - Removed duplicates in wrong directories (now fixed)
- ❌ **Redeclaration errors** - HeadToHead.swift, HistoryLogic.swift, Formatters.swift in wrong location (now fixed)

## Why This Happens
SourceKit (the Swift language server) sometimes fails to index Swift Package dependencies or cross-file symbols correctly. This is a known issue with complex Xcode projects that mix:
- Swift Packages (TiercadeCore)
- Multiple targets (App, Tests, UI Tests)
- Cross-platform code (#if os(tvOS))

## Verification
```bash
# The actual build succeeds:
xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' \
  -configuration Debug build
# ✅ BUILD SUCCEEDED

# SwiftLint also passes (with expected style warnings):
swiftlint
# ✅ Found 19 violations, 0 serious
```

## Workarounds
1. **Ignore the red squiggles** - Trust the build output, not the IDE
2. **Clean Build Folder** - Product → Clean Build Folder (⇧⌘K) may help
3. **Restart SourceKit** - CMD+Shift+P → "Swift: Restart Language Server"
4. **Use terminal build** - `xcodebuild` is the source of truth

## VS Code Users
Add to `.vscode/settings.json` (not tracked in git):
```json
{
  "swift.diagnosticsCollection": "keepSourceKit",
  "swift.diagnosticsStyle": "llvm",
  "files.exclude": {
    "**/.DS_Store": true,
    "**/._*": true,
    "build/": true
  }
}
```

## Bottom Line
**If the build succeeds, ship it.** SourceKit errors in the IDE are noise.
