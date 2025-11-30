#!/bin/bash
# shellcheck disable=SC2292,SC2250,SC2312
# SC2292: Use [ ] for bash 3.2 compatibility (macOS default)
# SC2250: Braces optional for readability in simple cases
# SC2312: Command piping is intentional, checked separately

# Note: Compatible with bash 3.2+ (macOS default)

# Default configuration
PLATFORMS=()
NO_LAUNCH=0
ENABLE_ADVANCED_GENERATION=""  # empty = use DEBUG setting, "1" = force enable, "0" = force disable

usage() {
  cat <<'USAGE'
Usage: ./build_install_launch.sh [platform] [options]

Platforms:
  (none)      Build all platforms (tvOS, iOS, iPadOS, macOS) - default
  all         Build all platforms (tvOS, iOS, iPadOS, macOS)
  tvos        Build tvOS only
  ios         Build iOS only
  ipad        Build for iPad (iPadOS)
  macos       Build macOS only
  mac         (alias for macos)

Options:
  --enable-advanced-generation   Force advanced generation feature flag on
  --disable-advanced-generation  Force advanced generation feature flag off
  --no-launch                    Skip installing and launching after build

Pre-build:
  SwiftFormat runs automatically before building (auto-fixes formatting)
  SwiftLint checks for errors (blocks build if errors found)

Examples:
  ./build_install_launch.sh                    # Build all platforms
  ./build_install_launch.sh all                # Build all platforms
  ./build_install_launch.sh tvos               # Build tvOS only
  ./build_install_launch.sh ipad               # Build for iPad mini only
  ./build_install_launch.sh macos --no-launch  # Build macOS only without launching
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    all|tvos|ios|ipad|macos|mac)
      PLATFORMS+=("$1")
      shift
      ;;
    --enable-advanced-generation)
      ENABLE_ADVANCED_GENERATION="1"
      shift
      ;;
    --disable-advanced-generation)
      ENABLE_ADVANCED_GENERATION="0"
      shift
      ;;
    --no-launch)
      NO_LAUNCH=1
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "❌ Unknown argument: $1"
      echo ""
      usage
      exit 1
      ;;
  esac
done

# Default to all platforms when no explicit platform argument provided
if [ ${#PLATFORMS[@]} -eq 0 ]; then
  PLATFORMS=("all")
fi

# Expand "all" to individual platforms
EXPANDED_PLATFORMS=()
for platform in "${PLATFORMS[@]}"; do
  case "$platform" in
    all)
      EXPANDED_PLATFORMS+=("tvos" "ios" "ipad" "macos")
      ;;
    mac)
      EXPANDED_PLATFORMS+=("macos")
      ;;
    *)
      EXPANDED_PLATFORMS+=("$platform")
      ;;
  esac
done

# Remove duplicates (simple bash 3.2 compatible approach)
FINAL_PLATFORMS=()
for platform in "${EXPANDED_PLATFORMS[@]}"; do
  duplicate=0
  for existing in "${FINAL_PLATFORMS[@]}"; do
    if [ "$platform" = "$existing" ]; then
      duplicate=1
      break
    fi
  done
  if [ $duplicate -eq 0 ]; then
    FINAL_PLATFORMS+=("$platform")
  fi
done

echo "🎯 Building platforms: ${FINAL_PLATFORMS[*]}"
if [ -n "$ENABLE_ADVANCED_GENERATION" ]; then
  if [ "$ENABLE_ADVANCED_GENERATION" = "1" ]; then
    echo "🔬 Advanced generation: ENABLED (forced)"
  else
    echo "🔬 Advanced generation: DISABLED (forced)"
  fi
else
  echo "🔬 Advanced generation: using DEBUG setting"
fi
echo ""

# Run SwiftFormat and SwiftLint before building
echo "🧹 Running pre-build lint checks..."

SWIFTFORMAT=$(which swiftformat 2>/dev/null || echo "")
SWIFTLINT=$(which swiftlint 2>/dev/null || echo "")

if [ -n "$SWIFTFORMAT" ]; then
  echo "   SwiftFormat: formatting..."
  "$SWIFTFORMAT" . --quiet 2>/dev/null || true
else
  echo "   ⚠️  SwiftFormat not found, skipping"
fi

if [ -n "$SWIFTLINT" ]; then
  echo "   SwiftLint: checking for errors..."
  LINT_ERRORS=$("$SWIFTLINT" lint --quiet 2>&1 | grep -c "error:" || true)
  if [ "$LINT_ERRORS" -gt 0 ]; then
    echo ""
    echo "❌ SwiftLint found $LINT_ERRORS error(s). Fix before building:"
    "$SWIFTLINT" lint --quiet 2>&1 | grep "error:"
    echo ""
    exit 1
  fi
  echo "   ✅ Lint checks passed"
else
  echo "   ⚠️  SwiftLint not found, skipping"
fi

echo ""

# Track results using parallel arrays (bash 3.2 compatible)
RESULT_PLATFORMS=()
RESULT_STATUS=()
RESULT_TIMES=()
OVERALL_START=$(date +%s)

# Build each platform
for PLATFORM in "${FINAL_PLATFORMS[@]}"; do
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Configure platform-specific settings
  case "$PLATFORM" in
    tvos)
      DESTINATION='platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest'
      DEVICE_NAME='Apple TV 4K (3rd generation)'
      BUNDLE_ID='eworthing.Tiercade'
      EMOJI="📺"
      PLATFORM_NAME="tvOS"
      ;;
    ios)
      DESTINATION='platform=iOS Simulator,name=iPhone 17 Pro,OS=latest'
      DEVICE_NAME='iPhone 17 Pro'
      BUNDLE_ID='eworthing.Tiercade'
      EMOJI="📱"
      PLATFORM_NAME="iOS"
      ;;
    ipad)
      DESTINATION='platform=iOS Simulator,name=iPad mini (A17 Pro),OS=latest'
      DEVICE_NAME='iPad mini (A17 Pro)'
      BUNDLE_ID='eworthing.Tiercade'
      EMOJI="📱"
      PLATFORM_NAME="iPad mini"
      ;;
    macos)
      DESTINATION='platform=macOS,name=My Mac'
      DEVICE_NAME='Mac'
      BUNDLE_ID='eworthing.Tiercade'
      EMOJI="💻"
      PLATFORM_NAME="macOS"
      ;;
    *)
      echo "❌ Unknown platform: $PLATFORM"
      RESULT_PLATFORMS+=("$PLATFORM")
      RESULT_STATUS+=("FAILED")
      RESULT_TIMES+=("")
      continue
      ;;
  esac

  PLATFORM_START=$(date +%s)

  echo "$EMOJI Building $PLATFORM_NAME..."
  echo ""

  # Clean
  echo "🧹 Cleaning..."
  if xcodebuild clean -project Tiercade.xcodeproj -scheme Tiercade -configuration Debug 2>&1 | grep -q "BUILD FAILED"; then
    echo "❌ Clean failed for $PLATFORM_NAME"
    RESULT_PLATFORMS+=("$PLATFORM")
    RESULT_STATUS+=("FAILED")
    RESULT_TIMES+=("")
    continue
  fi
  echo "✅ Clean complete"
  echo ""

  # Build
  echo "🔨 Building..."

  BUILD_SETTINGS=""
  if [ "$ENABLE_ADVANCED_GENERATION" = "1" ]; then
    BUILD_SETTINGS="-DFORCE_ENABLE_ADVANCED_GENERATION"
  elif [ "$ENABLE_ADVANCED_GENERATION" = "0" ]; then
    BUILD_SETTINGS="-DFORCE_DISABLE_ADVANCED_GENERATION"
  fi

  BUILD_FAILED=0
  BUILD_LOG="/tmp/tiercade_build_${PLATFORM}.log"

  if [ -n "$BUILD_SETTINGS" ]; then
    if ! xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
      -destination "$DESTINATION" \
      -configuration Debug \
      OTHER_SWIFT_FLAGS="$BUILD_SETTINGS" \
      build 2>&1 | tee "$BUILD_LOG" | grep -E "(BUILD|error:)"; then
      BUILD_FAILED=1
    fi
  else
    if ! xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
      -destination "$DESTINATION" \
      -configuration Debug \
      build 2>&1 | tee "$BUILD_LOG" | grep -E "(BUILD|error:)"; then
      BUILD_FAILED=1
    fi
  fi

  if [ "$BUILD_FAILED" -eq 1 ] || grep -q "BUILD FAILED" "$BUILD_LOG"; then
    echo "❌ Build failed for $PLATFORM_NAME"
    echo "   See log: /tmp/tiercade_build_${PLATFORM}.log"
    RESULT_PLATFORMS+=("$PLATFORM")
    RESULT_STATUS+=("FAILED")
    RESULT_TIMES+=("")
    continue
  fi

  echo "✅ Build complete"
  echo ""

  # Get build location
  DERIVED_DATA=$(xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
    -destination "$DESTINATION" \
    -showBuildSettings -configuration Debug 2>/dev/null | \
    grep 'BUILT_PRODUCTS_DIR =' | head -1 | sed 's/.*= //')

  APP_PATH="${DERIVED_DATA}/Tiercade.app"

  if [ ! -d "$APP_PATH" ]; then
    echo "❌ App not found at: $APP_PATH"
    RESULT_PLATFORMS+=("$PLATFORM")
    RESULT_STATUS+=("FAILED")
    RESULT_TIMES+=("")
    continue
  fi

  INFO_PLIST="$APP_PATH/Info.plist"
  if [ "$PLATFORM" = "macos" ]; then
    INFO_PLIST="$APP_PATH/Contents/Info.plist"
  fi

  BUILD_TIME=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$INFO_PLIST" 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
  echo "✅ Built at: $BUILD_TIME"

  PLATFORM_END=$(date +%s)
  PLATFORM_DURATION=$((PLATFORM_END - PLATFORM_START))
  echo "⏱️  Duration: ${PLATFORM_DURATION}s"

  # Launch if not --no-launch
  if [ "$NO_LAUNCH" = "0" ]; then
    echo ""
    if [ "$PLATFORM" = "tvos" ] || [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "ipad" ]; then
      echo "📦 Installing to $PLATFORM_NAME simulator..."
      xcrun simctl boot "$DEVICE_NAME" 2>/dev/null || true
      open -a Simulator
      sleep 2
      xcrun simctl uninstall "$DEVICE_NAME" "$BUNDLE_ID" 2>/dev/null || true
      xcrun simctl install "$DEVICE_NAME" "$APP_PATH"
      echo "✅ Installed"
      echo ""

      echo "🚀 Launching..."
      PID=$(xcrun simctl launch "$DEVICE_NAME" "$BUNDLE_ID" 2>&1 | awk '{print $NF}')
      echo "✅ Launched (PID: $PID)"
    else
      echo "🔓 Removing Gatekeeper quarantine attribute..."
      xattr -dr com.apple.quarantine "$APP_PATH" 2>/dev/null || true
      echo "✅ Quarantine removed"
      echo ""

      echo "🚀 Launching native macOS app..."
      open "$APP_PATH"
      echo "✅ Launched"
    fi
  else
    echo ""
    echo "🚫 Skipping launch (--no-launch specified)"
    echo "   App is at: $APP_PATH"
  fi

  # Record success
  RESULT_PLATFORMS+=("$PLATFORM")
  RESULT_STATUS+=("SUCCESS")
  RESULT_TIMES+=("$BUILD_TIME")
done

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 BUILD SUMMARY"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

OVERALL_END=$(date +%s)
OVERALL_DURATION=$((OVERALL_END - OVERALL_START))

SUCCESS_COUNT=0
FAILED_COUNT=0

# Print results (iterate through parallel arrays)
for i in "${!RESULT_PLATFORMS[@]}"; do
  PLATFORM="${RESULT_PLATFORMS[$i]}"
  STATUS="${RESULT_STATUS[$i]}"
  BUILD_TIME="${RESULT_TIMES[$i]}"

  case "$PLATFORM" in
    tvos) EMOJI="📺"; PLATFORM_NAME="tvOS" ;;
    ios) EMOJI="📱"; PLATFORM_NAME="iOS" ;;
    ipad) EMOJI="📱"; PLATFORM_NAME="iPad mini" ;;
    macos) EMOJI="💻"; PLATFORM_NAME="macOS" ;;
    *) EMOJI="❓"; PLATFORM_NAME="Unknown" ;;
  esac

  if [ "$STATUS" = "SUCCESS" ]; then
    echo "✅ $EMOJI $PLATFORM_NAME: SUCCESS ($BUILD_TIME)"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
  else
    echo "❌ $EMOJI $PLATFORM_NAME: FAILED"
    FAILED_COUNT=$((FAILED_COUNT + 1))
  fi
done

echo ""
echo "Total: $SUCCESS_COUNT succeeded, $FAILED_COUNT failed"
echo "Total time: ${OVERALL_DURATION}s"

if [ "$FAILED_COUNT" -gt 0 ]; then
  exit 1
fi
