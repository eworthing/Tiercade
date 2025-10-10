#!/bin/bash
set -e

echo "🧹 Cleaning..."
xcodebuild clean -project Tiercade.xcodeproj -scheme Tiercade -configuration Debug
echo "✅ Clean complete"
echo ""

echo "🔨 Building..."
xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' \
  -configuration Debug build
echo "✅ Build complete"
echo ""

# Get build location
DERIVED_DATA=$(xcodebuild -project Tiercade.xcodeproj -scheme Tiercade \
  -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation),OS=latest' \
  -showBuildSettings -configuration Debug 2>/dev/null | \
  grep 'BUILT_PRODUCTS_DIR =' | head -1 | sed 's/.*= //')

APP_PATH="${DERIVED_DATA}/Tiercade.app"

if [ ! -d "$APP_PATH" ]; then
  echo "❌ App not found at: $APP_PATH"
  exit 1
fi

BUILD_TIME=$(stat -f '%Sm' -t '%Y-%m-%d %H:%M:%S' "$APP_PATH/Info.plist")
echo "✅ Built at: $BUILD_TIME"
echo ""

echo "📦 Installing to simulator..."
xcrun simctl boot 'Apple TV 4K (3rd generation)' 2>/dev/null || true
open -a Simulator
sleep 2
xcrun simctl uninstall 'Apple TV 4K (3rd generation)' eworthin.Tiercade 2>/dev/null || true
xcrun simctl install 'Apple TV 4K (3rd generation)' "$APP_PATH"
echo "✅ Installed"
echo ""

echo "🚀 Launching..."
PID=$(xcrun simctl launch 'Apple TV 4K (3rd generation)' eworthin.Tiercade 2>&1 | awk '{print $NF}')
echo "✅ Launched (PID: $PID)"
echo "✅ Build time: $BUILD_TIME"
