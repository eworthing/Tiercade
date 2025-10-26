# Advanced Generation Feature Flag Control

## Overview

The `enableAdvancedGeneration` feature flag controls the unique list generation architecture:
- **Enabled**: Uses Generate → Dedup → Fill architecture with over-generation, client-side deduplication, and backfill
- **Disabled**: Falls back to simple client-side deduplication only

## Build Script Usage

### Default Behavior (Recommended)
```bash
./build_install_launch.sh catalyst
```
- Uses **DEBUG setting**: enabled in DEBUG builds, disabled in Release
- ✅ Safest for development (experimental code isolated)
- ⚠️ Note: tvOS doesn't support Apple Intelligence, so use Catalyst for testing feature flags

### Force Enable (For Testing Advanced Generation in Release)
```bash
./build_install_launch.sh catalyst --enable-advanced-generation
```
- Enables advanced generation **regardless of build configuration**
- Use case: Test advanced generation in Release builds before merging
- Verifies the advanced generation algorithm works correctly

### Force Disable (For Regression Testing)
```bash
./build_install_launch.sh catalyst --disable-advanced-generation
```
- Disables advanced generation **regardless of build configuration**
- Use case: Verify fallback code path (simple client-side dedup) still works correctly

## Implementation Details

### Swift Code
**File:** `Tiercade/State/AppleIntelligence+UniqueListGeneration.swift`

The feature flag is evaluated at compile-time via preprocessor directives:

```swift
enum UniqueListGenerationFlags {
    nonisolated(unsafe) static var enableAdvancedGeneration: Bool = {
        #if FORCE_ENABLE_ADVANCED_GENERATION
        return true
        #elseif FORCE_DISABLE_ADVANCED_GENERATION
        return false
        #elseif DEBUG
        return true
        #else
        return false
        #endif
    }()
}
```

### Build Script
**File:** `build_install_launch.sh`

The script:
1. Parses command-line arguments for `--enable-advanced-generation` or `--disable-advanced-generation`
2. Passes compiler flags via `OTHER_SWIFT_FLAGS` to xcodebuild:
   - `-DFORCE_ENABLE_ADVANCED_GENERATION=1` (when `--enable-advanced-generation`)
   - `-DFORCE_DISABLE_ADVANCED_GENERATION=1` (when `--disable-advanced-generation`)
3. Displays current feature flag state in build output for transparency

## Testing Scenarios

### 1. Development Build (All Code Paths)
```bash
# Run in DEBUG configuration with advanced generation enabled
./build_install_launch.sh catalyst
# → 🔬 Advanced generation: using DEBUG setting
```
✅ Tests all code paths including experimental features

### 2. Release Candidate Testing
```bash
# Build in Release but force-enable advanced generation to test before merge
./build_install_launch.sh catalyst --enable-advanced-generation
# → 🔬 Advanced generation: ENABLED (forced)
```
✅ Verifies advanced generation works in Release optimization level

### 3. Fallback Code Path Verification
```bash
# Build with advanced generation explicitly disabled
./build_install_launch.sh catalyst --disable-advanced-generation
# → 🔬 Advanced generation: DISABLED (forced)
```
✅ Confirms simple deduplication fallback still functions

## Examples

### CI/CD Integration
```bash
# Build matrix for comprehensive testing on Catalyst (iOS variant with AI support)
./build_install_launch.sh catalyst                              # Default
./build_install_launch.sh catalyst --enable-advanced-generation  # Force enable
./build_install_launch.sh catalyst --disable-advanced-generation # Force disable

# Run tests on each variant
swift test
```

### Local Development Workflow
```bash
# Normal development - uses DEBUG setting (advanced gen enabled)
./build_install_launch.sh catalyst

# Regression testing - ensure fallback works without advanced generation
./build_install_launch.sh catalyst --disable-advanced-generation

# Before PR merge - verify advanced gen in Release-like conditions
./build_install_launch.sh catalyst --enable-advanced-generation
```

## Compile-Time Behavior

All three flags are resolved **at compile time**, not runtime:
- Different binaries are produced for each configuration
- Zero runtime overhead - flag state is baked into the binary
- Safe for shipping: compiler strips unreachable code paths

## See Also

- `Tiercade/State/AppleIntelligence+UniqueListGeneration.swift` - Feature flag definition
- `build_install_launch.sh` - Build script with flag support
