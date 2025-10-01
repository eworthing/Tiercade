#!/bin/bash
# Quick test to verify the image fetching tools are working

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🧪 Testing Tiercade Image Fetching Tools"
echo

# Test 1: Check Node.js
echo "1. Checking Node.js..."
if ! command -v node &> /dev/null; then
    echo "   ❌ Node.js not found. Please install Node.js from https://nodejs.org/"
    exit 1
fi
NODE_VERSION=$(node --version)
echo "   ✅ Node.js found: $NODE_VERSION"

# Test 2: Check dependencies
echo "2. Checking npm dependencies..."
cd "$SCRIPT_DIR"
if [ ! -d "node_modules" ]; then
    echo "   ⚠️  Dependencies not installed. Installing..."
    npm install
fi
echo "   ✅ Dependencies installed"

# Test 3: Validate fetch_media_and_thumb.js syntax
echo "3. Validating fetch_media_and_thumb.js..."
node -c fetch_media_and_thumb.js
echo "   ✅ Script syntax valid"

# Test 4: Check if script shows help
echo "4. Testing script help..."
if node fetch_media_and_thumb.js 2>&1 | grep -q "Usage:"; then
    echo "   ✅ Script help working"
else
    echo "   ❌ Script help not working"
    exit 1
fi

# Test 5: Check TMDb API key
echo "5. Checking TMDb API key..."
if [ -z "$TMDB_API_KEY" ]; then
    echo "   ⚠️  TMDB_API_KEY not set"
    echo "      To enable TMDb features:"
    echo "      export TMDB_API_KEY='your-api-key-here'"
    echo "      Get free key at: https://www.themoviedb.org/settings/api"
else
    echo "   ✅ TMDb API key found (${#TMDB_API_KEY} characters)"
fi

# Test 6: Check Xcode assets path
echo "6. Checking Xcode assets path..."
ASSETS_PATH="$SCRIPT_DIR/../Tiercade/Assets.xcassets"
if [ -d "$ASSETS_PATH" ]; then
    echo "   ✅ Assets.xcassets found at: $ASSETS_PATH"
else
    echo "   ⚠️  Assets.xcassets not found at expected location"
fi

# Test 7: Create a minimal test file
echo "7. Running minimal test..."
TEST_FILE="$SCRIPT_DIR/temp_bundled/test-minimal.json"
mkdir -p "$(dirname "$TEST_FILE")"
cat > "$TEST_FILE" << 'EOF'
{
  "schemaVersion": 1,
  "projectId": "test-minimal",
  "title": "Test Project",
  "items": {}
}
EOF

# Run the script without TMDb (should work without API key)
if node fetch_media_and_thumb.js "$TEST_FILE" --out "$TEST_FILE.out" 2>&1 | grep -q "Media fetch complete"; then
    echo "   ✅ Script execution successful"
    rm -f "$TEST_FILE" "$TEST_FILE.out"
else
    echo "   ❌ Script execution failed"
    exit 1
fi

echo
echo "✅ All tests passed!"
echo
echo "Next steps:"
echo "1. Set TMDB_API_KEY if you want automatic image fetching"
echo "2. Run: ./fetch_bundled_images.sh"
echo "3. Check tools/README_IMAGES.md for complete documentation"
