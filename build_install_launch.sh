#!/bin/bash
set -e

# Default configuration
PLATFORM=""
NO_LAUNCH=0
ENABLE_ADVANCED_GENERATION=""  # empty = use DEBUG setting, "1" = force enable, "0" = force disable

usage() {
  cat <<'USAGE'
Usage: ./build_install_launch.sh [platform] [options]

Platforms:
  tvos        (default)
  macos
  mac         (alias for macos)

Options:
  --enable-advanced-generation   Force advanced generation feature flag on
  --disable-advanced-generation  Force advanced generation feature flag off
  --no-launch                    Skip installing and launching after build

Examples:
  ./build_install_launch.sh tvos
  ./build_install_launch.sh macos --enable-advanced-generation --no-launch
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    tvos|macos|mac)
      PLATFORM="$1"
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

# Default to tvOS when no explicit platform argument provided
if [ -z "$PLATFORM" ]; then
  PLATFORM="tvos"
fi

case "$PLATFORM" in
  tvos)
    DESTINATION='platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest'
    DEVICE_NAME='Apple TV 4K (3rd generation)'
    BUNDLE_ID='eworthing.Tiercade'
    EMOJI="📺"
    ;;
  macos|mac)
    DESTINATION='platform=macOS,name=My Mac'
    DEVICE_NAME='Mac'
    BUNDLE_ID='eworthing.Tiercade'
    EMOJI="💻"
    ;;
  *)
    echo "❌ Unknown platform: $PLATFORM"
    echo ""
    usage
    exit 1
    ;;
esac

echo "$EMOJI Building for $PLATFORM..."
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

echo "🧹 Cleaning..."
xcodebuild clean -project Tiercade.xcodeproj -scheme Tiercade -configuration Debug
echo "✅ Clean complete"
echo ""

echo "🔨 Building..."

# Build settings for feature flags
BUILD_SETTINGS=""
if [ "$ENABLE_ADVANCED_GENERATION" = "1" ]; then
  BUILD_SETTINGS="-DFORCE_ENABLE_ADVANCED_GENERATION"
elif [ "$ENABLE_ADVANCED_GENERATION" = "0" ]; then
  BUILD_SETTINGS="-DFORCE_DISABLE_ADVANCED_GENERATION"
fi

if [ -n "$BUILD_SETTINGS" ]; then
  xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
    -destination "$DESTINATION" \
    -configuration Debug \
    OTHER_SWIFT_FLAGS="$BUILD_SETTINGS" \
    build
else
  xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
    -destination "$DESTINATION" \
    -configuration Debug \
    build
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
  exit 1
fi

INFO_PLIST="$APP_PATH/Info.plist"
if [ "$PLATFORM" = "macos" ] || [ "$PLATFORM" = "mac" ]; then
  INFO_PLIST="$APP_PATH/Contents/Info.plist"
fi

BUILD_TIME=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$INFO_PLIST" 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
echo "✅ Built at: $BUILD_TIME"
echo ""


# Check if we should launch
if [ "$NO_LAUNCH" = "1" ]; then
  echo "🚫 Skipping launch (--no-launch specified)"
  echo "✅ Build complete. App is at: $APP_PATH"
  exit 0
fi

if [ "$PLATFORM" = "tvos" ]; then
  echo "📦 Installing to tvOS simulator..."
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
  echo "🚀 Launching native macOS app..."
  open "$APP_PATH"
  echo "✅ Launched"
fi

echo "✅ Build time: $BUILD_TIME"
