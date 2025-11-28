#!/bin/bash
# Automated AI Prompt Test Runner
# Runs all test suites in sequence and generates comprehensive reports

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
# Running enhanced-pilot to measure token cap fix impact
TEST_SUITES=(
    # "quick-smoke"
    # "standard-prompt-test"
    # "n50-validation"
    "enhanced-pilot"
    # "diversity-comparison"
    # "full-acceptance"
)

# shellcheck disable=SC2034  # Reserved for future direct app invocation
MACOS_APP_PATH="$HOME/Library/Developer/Xcode/DerivedData/Tiercade-*/Build/Products/Debug/Tiercade.app/Contents/MacOS/Tiercade"
# shellcheck disable=SC2034  # Reserved for future temp file operations
TEMP_DIR=$(mktemp -d)
RESULTS_DIR="./test-results/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${PURPLE}🧪 TIERCADE AI PROMPT TEST SUITE RUNNER${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${BLUE}Test Results Directory: ${RESULTS_DIR}${NC}"
echo -e "${BLUE}Test Start Time: $(date)${NC}"
echo ""

# Ensure macOS app is built
if [ ! -f build_install_launch.sh ]; then
    echo -e "${RED}❌ Error: build_install_launch.sh not found${NC}"
    echo -e "${RED}   Please run this script from the Tiercade repository root${NC}"
    exit 1
fi

echo -e "${YELLOW}🔨 Building macOS app...${NC}"
./build_install_launch.sh macos --no-launch || {
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
}
echo -e "${GREEN}✅ Build complete${NC}"
echo ""

# Find the actual app path - exclude Index.noindex
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/Tiercade-* -name "Tiercade.app" -path "*/Build/Products/Debug/*" -not -path "*/Index.noindex/*" 2>/dev/null | head -n 1)
if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ Could not find Tiercade.app in DerivedData${NC}"
    exit 1
fi

APP_EXECUTABLE="$APP_PATH/Contents/MacOS/Tiercade"
if [ ! -f "$APP_EXECUTABLE" ]; then
    echo -e "${RED}❌ App executable not found at: ${APP_EXECUTABLE}${NC}"
    exit 1
fi
echo -e "${BLUE}📱 Found app: ${APP_EXECUTABLE}${NC}"
echo ""

# Initialize summary
SUMMARY_FILE="$RESULTS_DIR/00_SUMMARY.md"
cat > "$SUMMARY_FILE" <<EOF
# Tiercade AI Prompt Test Results

**Test Run Date:** $(date)
**macOS Version:** $(sw_vers -productVersion)
**Swift Version:** $(swift --version | head -n 1)

---

## Test Suites Executed

EOF

TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0
SUITE_RESULTS=()

# Run each test suite
for suite_id in "${TEST_SUITES[@]}"; do
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}🧪 Running Test Suite: ${suite_id}${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Clean temp files before each run
    rm -f ~/Library/Containers/Tiercade/Data/tmp/tiercade_unified_test_report.json
    rm -f ~/Library/Containers/Tiercade/Data/tmp/tiercade_prompt_test_debug.log
    rm -f "$TMPDIR"tiercade_unified_test_report.json
    rm -f "$TMPDIR"tiercade_prompt_test_debug.log

    # Run the test suite
    START_TIME=$(date +%s)
    EXIT_CODE=0

    echo -e "${BLUE}⏳ Starting test suite at $(date +%H:%M:%S)...${NC}"
    "$APP_EXECUTABLE" -runUnifiedTests "$suite_id" 2>&1 | tee "$RESULTS_DIR/${suite_id}_output.log" || EXIT_CODE=$?

    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))

    echo ""
    echo -e "${BLUE}⏱️  Test suite completed in ${DURATION}s${NC}"

    # Try to find the report in multiple locations (macOS sandboxes the app)
    REPORT_PATH=""
    for location in \
        ~/Library/Containers/eworthing.Tiercade/Data/tmp/ \
        ~/Library/Containers/Tiercade/Data/tmp/ \
        "$TMPDIR" \
        /tmp/
    do
        if [ -f "${location}tiercade_unified_test_report.json" ]; then
            REPORT_PATH="${location}tiercade_unified_test_report.json"
            echo -e "${BLUE}📄 Found report at: ${REPORT_PATH}${NC}"
            break
        fi
    done

    # Copy results to our results directory
    if [ -n "$REPORT_PATH" ] && [ -f "$REPORT_PATH" ]; then
        cp "$REPORT_PATH" "$RESULTS_DIR/${suite_id}_report.json"
        echo -e "${GREEN}✅ Report copied to: $RESULTS_DIR/${suite_id}_report.json${NC}"

        # Extract key metrics from JSON report
        SUCCESS_RATE=$(python3 -c "
import json, sys
try:
    with open('$RESULTS_DIR/${suite_id}_report.json') as f:
        data = json.load(f)
        total = data.get('totalRuns', 0)
        success = data.get('successfulRuns', 0)
        rate = (success / max(1, total)) * 100 if total > 0 else 0
        print(f'{rate:.1f}')
except Exception as e:
    print('N/A')
" 2>/dev/null || echo "N/A")

        # Update totals
        if [ -f "$RESULTS_DIR/${suite_id}_report.json" ]; then
            RUNS=$(python3 -c "
import json
try:
    with open('$RESULTS_DIR/${suite_id}_report.json') as f:
        data = json.load(f)
        print(data.get('totalRuns', 0))
except:
    print(0)
" 2>/dev/null || echo 0)

            PASSED=$(python3 -c "
import json
try:
    with open('$RESULTS_DIR/${suite_id}_report.json') as f:
        data = json.load(f)
        print(data.get('successfulRuns', 0))
except:
    print(0)
" 2>/dev/null || echo 0)

            TOTAL_TESTS=$((TOTAL_TESTS + RUNS))
            TOTAL_PASSED=$((TOTAL_PASSED + PASSED))
            TOTAL_FAILED=$((TOTAL_FAILED + RUNS - PASSED))
        fi

        # Add to summary
        if [ "$EXIT_CODE" -eq 0 ]; then
            SUITE_RESULTS+=("${GREEN}✅ ${suite_id}: PASSED (${SUCCESS_RATE}% success, ${DURATION}s)${NC}")
            cat >> "$SUMMARY_FILE" <<EOF
### ✅ ${suite_id}

- **Status:** PASSED
- **Success Rate:** ${SUCCESS_RATE}%
- **Duration:** ${DURATION}s
- **Report:** [\`${suite_id}_report.json\`](./${suite_id}_report.json)
- **Output Log:** [\`${suite_id}_output.log\`](./${suite_id}_output.log)

EOF
        else
            SUITE_RESULTS+=("${RED}❌ ${suite_id}: FAILED (${SUCCESS_RATE}% success, ${DURATION}s)${NC}")
            cat >> "$SUMMARY_FILE" <<EOF
### ❌ ${suite_id}

- **Status:** FAILED (exit code: $EXIT_CODE)
- **Success Rate:** ${SUCCESS_RATE}%
- **Duration:** ${DURATION}s
- **Report:** [\`${suite_id}_report.json\`](./${suite_id}_report.json)
- **Output Log:** [\`${suite_id}_output.log\`](./${suite_id}_output.log)

EOF
        fi
    else
        echo -e "${YELLOW}⚠️  Report file not found in any expected location${NC}"
        SUITE_RESULTS+=("${YELLOW}⚠️  ${suite_id}: NO REPORT (${DURATION}s)${NC}")
        cat >> "$SUMMARY_FILE" <<EOF
### ⚠️  ${suite_id}

- **Status:** NO REPORT
- **Duration:** ${DURATION}s
- **Output Log:** [\`${suite_id}_output.log\`](./${suite_id}_output.log)

EOF
    fi

    # Copy debug log if it exists
    for location in ~/Library/Containers/eworthing.Tiercade/Data/tmp/ ~/Library/Containers/Tiercade/Data/tmp/ "$TMPDIR" /tmp/; do
        if [ -f "${location}tiercade_prompt_test_debug.log" ]; then
            cp "${location}tiercade_prompt_test_debug.log" "$RESULTS_DIR/${suite_id}_debug.log"
            echo -e "${GREEN}✅ Debug log copied${NC}"
            break
        fi
    done

    echo ""
    echo -e "${BLUE}Waiting 5 seconds before next test suite...${NC}"
    sleep 5
done

# Generate final summary
echo ""
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${PURPLE}📊 TEST SUMMARY${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

for result in "${SUITE_RESULTS[@]}"; do
    echo -e "$result"
done

echo ""
echo -e "${BLUE}Total Test Runs: ${TOTAL_TESTS}${NC}"
echo -e "${GREEN}Passed: ${TOTAL_PASSED}${NC}"
echo -e "${RED}Failed: ${TOTAL_FAILED}${NC}"

OVERALL_RATE=0
if [ "$TOTAL_TESTS" -gt 0 ]; then
    OVERALL_RATE=$(python3 -c "print(f'{($TOTAL_PASSED / $TOTAL_TESTS) * 100:.1f}')" 2>/dev/null || echo "0")
fi
echo -e "${BLUE}Overall Success Rate: ${OVERALL_RATE}%${NC}"
echo ""
echo -e "${BLUE}All results saved to: ${RESULTS_DIR}${NC}"
echo -e "${BLUE}Summary report: ${SUMMARY_FILE}${NC}"
echo ""

# Finalize summary markdown
cat >> "$SUMMARY_FILE" <<EOF

---

## Overall Statistics

- **Total Test Runs:** $TOTAL_TESTS
- **Passed:** $TOTAL_PASSED
- **Failed:** $TOTAL_FAILED
- **Overall Success Rate:** ${OVERALL_RATE}%

---

## Analysis

### Success Rates by Suite

EOF

# Generate a simple bar chart in markdown
for suite_id in "${TEST_SUITES[@]}"; do
    if [ -f "$RESULTS_DIR/${suite_id}_report.json" ]; then
        SUCCESS_RATE=$(python3 -c "
import json
try:
    with open('$RESULTS_DIR/${suite_id}_report.json') as f:
        data = json.load(f)
        total = data.get('totalRuns', 0)
        success = data.get('successfulRuns', 0)
        rate = (success / max(1, total)) * 100 if total > 0 else 0
        print(f'{rate:.1f}')
except:
    print('0.0')
" 2>/dev/null || echo "0.0")

        # Create a simple progress bar
        BARS=$(python3 -c "print('█' * int(float('$SUCCESS_RATE') / 5))" 2>/dev/null || echo "")

        cat >> "$SUMMARY_FILE" <<EOF
- **${suite_id}:** ${SUCCESS_RATE}% ${BARS}
EOF
    fi
done

cat >> "$SUMMARY_FILE" <<EOF

---

## Files Generated

EOF

# List all files in the results directory
cd "$RESULTS_DIR"
for file in *; do
    if [ "$file" != "00_SUMMARY.md" ]; then
        # Use stat for macOS-compatible file size (avoids SC2012)
        SIZE=$(stat -f%z "$file" 2>/dev/null | awk '{
            if ($1 >= 1048576) printf "%.1fM", $1/1048576
            else if ($1 >= 1024) printf "%.1fK", $1/1024
            else printf "%dB", $1
        }')
        echo "- \`$file\` ($SIZE)" >> "$SUMMARY_FILE"
    fi
done

echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ All tests complete!${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Exit with failure if any tests failed
if [ "$TOTAL_FAILED" -gt 0 ]; then
    exit 1
else
    exit 0
fi
