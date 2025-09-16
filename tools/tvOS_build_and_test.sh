#!/usr/bin/env zsh
# tools/tvOS_build_and_test.sh
# Robust tvOS build + smoke-test launcher.
# Usage: ./tools/tvOS_build_and_test.sh [SIM_UDID] [SCHEME]

LOG=/tmp/tiercade_build_and_test.log
SIM_UDID=${1:-08740B5F-A5BF-4E06-AF6E-AEA889E21999}
SCHEME=${2:-Tiercade}
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "Build+Test started: $(date)" > $LOG
echo "REPO_ROOT=$REPO_ROOT" >> $LOG

echo "Discovering Xcode project..." | tee -a $LOG
# Prefer top-level .xcodeproj, fall back to any found in repo
XCODEPROJ=""
if [ -f "$REPO_ROOT/Tiercade.xcodeproj/project.pbxproj" ]; then
  XCODEPROJ="$REPO_ROOT/Tiercade.xcodeproj"
else
  XCODEPROJ=$(find "$REPO_ROOT" -maxdepth 2 -name "*.xcodeproj" -print -quit || true)
fi

echo "Found XCODEPROJ=$XCODEPROJ" | tee -a $LOG
if [ -z "$XCODEPROJ" ]; then
  echo "ERROR: No .xcodeproj found under $REPO_ROOT" | tee -a $LOG
  echo "Candidates:" >> $LOG
  find "$REPO_ROOT" -maxdepth 3 -name "*.xcodeproj" >> $LOG 2>&1 || true
  exit 1
fi

DERIVED=/tmp/tiercade_derived
mkdir -p "$DERIVED"

echo "Building scheme $SCHEME for tvOS simulator (udid=$SIM_UDID)..." | tee -a $LOG
xcodebuild -project "$XCODEPROJ" -scheme "$SCHEME" -sdk appletvsimulator -destination "id=$SIM_UDID" -derivedDataPath "$DERIVED" clean build >> $LOG 2>&1 || echo "build failed; see $LOG" | tee -a $LOG

# Try to find the built .app
APP_PATH=$(find "$DERIVED/Build/Products" -type d -name "*.app" | grep -i "Tiercade" | head -n 1 || true)
if [ -z "$APP_PATH" ]; then
  # try shallower search
  APP_PATH=$(find "$DERIVED" -type d -name "*.app" | head -n 1 || true)
fi

echo "APP_PATH=$APP_PATH" | tee -a $LOG
if [ -n "$APP_PATH" ]; then
  echo "Installing app to simulator $SIM_UDID" | tee -a $LOG
  xcrun simctl install "$SIM_UDID" "$APP_PATH" >> $LOG 2>&1 || echo "install failed" | tee -a $LOG

  # Auto-detect bundle identifier from built app Info.plist to avoid mismatches
  BUNDLE_ID=""
  if [ -f "$APP_PATH/Info.plist" ]; then
    # Prefer PlistBuddy if available for robust reading
    if command -v /usr/libexec/PlistBuddy >/dev/null 2>&1; then
      BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$APP_PATH/Info.plist" 2>/dev/null || true)
    else
      BUNDLE_ID=$(plutil -p "$APP_PATH/Info.plist" 2>/dev/null | sed -n 's/.*CFBundleIdentifier" => "\([^"]*\)".*/\1/p' || true)
    fi
  fi
  # Fallback to env SCHEME-derived or provided value if detection failed
  if [ -z "$BUNDLE_ID" ]; then
    echo "Warning: could not detect CFBundleIdentifier from app; using default eworthing.Tiercade" | tee -a $LOG
    BUNDLE_ID=${BUNDLE_ID:-eworthing.Tiercade}
  fi

  echo "Running UI test target on simulator (will collect artifacts to /tmp)..." | tee -a $LOG
  # Run the dedicated UI test (SmokeTests) which writes screenshots to /tmp
  # Note: UI test may fail due to simulator issues, but we continue to collect artifacts
  UI_TEST_EXIT=0
  xcodebuild test -project "$XCODEPROJ" -scheme "$SCHEME" -destination "platform=tvOS Simulator,id=$SIM_UDID" -derivedDataPath "$DERIVED" -only-testing:TiercadeUITests/SmokeTests/testSmokeRemote -skip-testing:TiercadeTests >> $LOG 2>&1 || UI_TEST_EXIT=$?
  if [ $UI_TEST_EXIT -ne 0 ]; then
    echo "WARNING: UI test failed (exit code $UI_TEST_EXIT), but continuing to collect artifacts" | tee -a $LOG
  else
    echo "UI test passed" | tee -a $LOG
  fi

  # After UI test run, also run the legacy smoke script to capture sim-level screenshots and app container logs
  ./tools/tvOS_smoketest.sh "$SIM_UDID" "$BUNDLE_ID" >> $LOG 2>&1 || echo "smoketest script failed" | tee -a $LOG
else
  echo "No .app built. Check /tmp/tiercade_build_and_test.log for xcodebuild output." | tee -a $LOG
fi

echo "Build+Test finished: $(date)" | tee -a $LOG

echo "=== ARTIFACTS SUMMARY ===" | tee -a $LOG
echo "UI Test Screenshots:" | tee -a $LOG
ls -la /tmp/tiercade_ui_*.png 2>/dev/null || echo "  No UI test screenshots found" | tee -a $LOG
echo "App Debug Log:" | tee -a $LOG
ls -la /tmp/tiercade_debug.log 2>/dev/null || echo "  No app debug log found" | tee -a $LOG
echo "Legacy Smoke Test Artifacts:" | tee -a $LOG
ls -la /tmp/tiercade_*.png /tmp/tiercade_smoketest.log 2>/dev/null || echo "  No legacy artifacts found" | tee -a $LOG
echo "Build Log: $LOG" | tee -a $LOG

echo "Done. Full log: $LOG"
