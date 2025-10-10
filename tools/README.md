# Tiercade Tools

This directory contains utility scripts for building, testing, and managing Tiercade assets.

## Table of Contents

- [Image Fetching & Asset Management](#image-fetching--asset-management)
- [tvOS Building & Testing](#tvos-building--testing)
- [Schema Validation](#schema-validation)

---

## Image Fetching & Asset Management

Automatically fetch images from TMDb and organize them into Xcode asset catalogs for bundled tier lists.

### Quick Start

```bash
# Set up TMDb API key (free from themoviedb.org)
export TMDB_API_KEY='your-api-key-here'

# Fetch all bundled images
./tools/fetch_bundled_images.sh
```

**See [README_IMAGES.md](./README_IMAGES.md) for complete documentation.**

### Manual Usage

```bash
node fetch_media_and_thumb.js project.json \
    --tmdb \
    --xcode-assets ../Tiercade/Assets.xcassets \
    --asset-group "BundledTierlists/Custom"
```

---

## tvOS Building & Testing

Use **VS Code tasks** for the development workflow:

### Daily Development

In VS Code, run the task: **"Build, Install & Launch tvOS"**
- Builds the app for tvOS simulator
- Finds the app in DerivedData (correct location, not stale builds)
- Shows actual build timestamp
- Boots simulator, uninstalls old version, installs fresh build
- Launches the app

Or use the keyboard shortcut (configure in VS Code keybindings).

### Manual Build Only

Run task: **"Build tvOS Tiercade (Debug)"** - just builds without installing.

### Clean Build

Run task: **"Clean Build tvOS"** - cleans derived data before rebuilding.

## UI Test Details

The `TiercadeUITests/SmokeTests.swift` test:
- Launches the app with `-uiTest` launch argument (app code may enable additional test-only hooks when this arg is present)
- Captures before/after screenshots and writes them to `/tmp`
- Uses `XCUIRemote` to simulate Apple TV remote presses
- Asserts presence of toolbar buttons by accessibility identifiers (see `Tiercade/Views/MainAppView.swift` for identifiers such as `Toolbar_H2H` and `Toolbar_Randomize`)

## Debugging Tips

1. **Simulator Issues**: If UI tests fail with launch errors, try:
   - Boot the simulator: `xcrun simctl boot <UDID>`
   - Reset simulator: `xcrun simctl erase <UDID>`

2. **Missing Artifacts**: Check the build log for errors. Note: the script is tolerant of UI test failures and will continue to collect artifacts in most cases. If the build fails, the script exits non-zero.

3. **App Not Responding**: Verify accessibility identifiers are set on UI elements in the SwiftUI code. See `Tiercade/Views/MainAppView.swift` and `Tiercade/Views/ContentView+Overlays.swift` for examples.

## Manual Testing

For manual testing without the script:

```bash
# Build and install
xcodebuild -project Tiercade.xcodeproj -scheme Tiercade -sdk appletvsimulator -destination "id=<SIM_UDID>" build
xcrun simctl install <SIM_UDID> <path/to/Tiercade.app>

# Launch and test manually
xcrun simctl launch <SIM_UDID> eworthing.Tiercade
```

## CI Integration

The `tools/tvOS_build_and_test.sh` script is designed for CI:
- The script treats build failures as fatal and exits with non-zero status
- UI test failures are captured and logged but the script attempts to continue so artifacts can be collected (this helps debugging flaky simulator runs)
- All artifacts are collected to `/tmp` by default; make sure your CI job collects those files as build artifacts