# Tiercade tvOS Debugging and Testing

This document describes the automated testing and debugging setup for Tiercade on tvOS.

## Quick Start

Run the full build + test + artifact collection:

```bash
./tools/tvOS_build_and_test.sh
```

This will:
- Build the app for tvOS simulator
- Run UI tests (SmokeTests) to exercise toolbar and overlays
- Capture screenshots and debug logs
- Run legacy smoke tests for additional coverage

## Artifacts

After running tests, check `/tmp` for:

- `tiercade_ui_before.png` / `tiercade_ui_after.png` - UI test screenshots
- `tiercade_debug.log` - App debug log from simulator
- `tiercade_before.png` / `tiercade_after.png` - Legacy smoke test screenshots
- `tiercade_build_and_test.log` - Full build and test log

## UI Test Details

The `TiercadeUITests/SmokeTests.swift` test:
- Launches the app with `-uiTest` argument
- Captures before/after screenshots
- Uses `XCUIRemote` to simulate Apple TV remote presses
- Asserts presence of toolbar buttons by accessibility identifiers

## Debugging Tips

1. **Simulator Issues**: If UI tests fail with launch errors, try:
   - Boot the simulator: `xcrun simctl boot <UDID>`
   - Reset simulator: `xcrun simctl erase <UDID>`

2. **Missing Artifacts**: Check the build log for errors. UI tests may fail but still produce some artifacts.

3. **App Not Responding**: Verify accessibility identifiers are set on UI elements in the SwiftUI code.

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
- Returns non-zero exit code only on build failures
- UI test failures are logged but don't stop the script
- All artifacts are collected to `/tmp` for easy upload