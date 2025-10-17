#!/bin/bash
set -e

# Default to tvOS, can be overridden with argument
PLATFORM="${1:-tvos}"

case "$PLATFORM" in
  tvos)
    DESTINATION='platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest'
    DEVICE_NAME='Apple TV 4K (3rd generation)'
    BUNDLE_ID='eworthing.Tiercade'
    EMOJI="📺"
    ;;
  catalyst|mac)
    DESTINATION='platform=macOS,variant=Mac Catalyst'
    DEVICE_NAME='Mac'
    BUNDLE_ID='eworthing.Tiercade'
    EMOJI="💻"
    ;;
  *)
    echo "❌ Unknown platform: $PLATFORM"
    echo "Usage: $0 [tvos|catalyst|mac]"
    exit 1
    ;;
esac

echo "$EMOJI Building for $PLATFORM..."
echo ""

echo "🧹 Cleaning..."
xcodebuild clean -project Tiercade.xcodeproj -scheme Tiercade -configuration Debug
echo "✅ Clean complete"
echo ""

echo "🔨 Building..."
xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
  -destination "$DESTINATION" \
  -configuration Debug build
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
if [ "$PLATFORM" = "catalyst" ] || [ "$PLATFORM" = "mac" ]; then
  INFO_PLIST="$APP_PATH/Contents/Info.plist"
fi

BUILD_TIME=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$INFO_PLIST" 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
echo "✅ Built at: $BUILD_TIME"
echo ""

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
  echo "🚀 Launching Mac Catalyst app..."
  open "$APP_PATH"
  echo "✅ Launched"
fi

echo "✅ Build time: $BUILD_TIME"
