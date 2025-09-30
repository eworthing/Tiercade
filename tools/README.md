# Tiercade tvOS Debugging and Testing

This document describes the automated testing and debugging setup for Tiercade on tvOS (OS 26.0+).

## Quick Start

Run the full build + test + artifact collection:

```bash
./tools/tvOS_build_and_test.sh
```

This will:
- Build the app for the tvOS 26.0+ simulator
- Run UI tests (SmokeTests) to exercise toolbar and overlays
- Capture screenshots and debug logs
- Run legacy smoke tests for additional coverage

## Artifacts

After running tests, check `/tmp` for the artifacts (the script writes artifacts to `/tmp` by default):

- `tiercade_ui_before.png` / `tiercade_ui_after.png` - UI test screenshots
- `tiercade_debug.log` - App debug log captured by the app
- `tiercade_before.png` / `tiercade_after.png` - Legacy smoke test screenshots
- `tiercade_build_and_test.log` - Full build and test log

If you run the script on CI, collect these files as build artifacts for debugging failures.

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