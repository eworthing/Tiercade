#!/bin/bash

# Automated Test Runner for Tiercade T3_Backfill Tests
# This script builds, launches, monitors, and analyzes test results automatically

set -e

# Configuration
PROJECT_DIR="/Users/Shared/git/Tiercade"
DEBUG_DIR="/tmp/tiercade_debug"
TELEMETRY_FILE="$HOME/Library/Containers/eworthing.Tiercade/Data/tmp/unique_list_runs.jsonl"
REPORT_FILE="$HOME/Library/Containers/eworthing.Tiercade/Data/tmp/tiercade_acceptance_test_report.json"
LOG_FILE="/tmp/tiercade_test_run_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to log with timestamp
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

# Function to clean up old data
cleanup() {
    log "🧹 Cleaning up old test data..."

    # Kill any running instances
    killall Tiercade 2>/dev/null || true

    # Backup old telemetry if exists
    if [ -f "$TELEMETRY_FILE" ]; then
        cp "$TELEMETRY_FILE" "$TELEMETRY_FILE.backup_$(date +%Y%m%d_%H%M%S)"
        > "$TELEMETRY_FILE"
    fi

    # Clean debug directory
    rm -rf "$DEBUG_DIR"
    mkdir -p "$DEBUG_DIR"

    # Remove old report
    rm -f "$REPORT_FILE"

    log "✅ Cleanup complete"
}

# Function to build the app
build_app() {
    log "🔨 Building Tiercade with advanced generation enabled..."

    cd "$PROJECT_DIR"

    # Build with feature flag (force rebuild to pick up fixes)
    ./build_install_launch.sh catalyst --enable-advanced-generation --no-launch

    if [ $? -eq 0 ]; then
        log "✅ Build successful"
        return 0
    else
        error "Build failed!"
        return 1
    fi
}

# Function to launch app with test flag
launch_tests() {
    log "🚀 Launching Tiercade with acceptance tests..."

    # Find the app
    APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "Tiercade.app" -path "*/Debug-maccatalyst/*" 2>/dev/null | head -1)

    if [ -z "$APP_PATH" ]; then
        error "Could not find Tiercade.app!"
        return 1
    fi

    # Launch with test flag
    "$APP_PATH/Contents/MacOS/Tiercade" -runAcceptanceTests &
    APP_PID=$!

    log "✅ Launched with PID: $APP_PID"
    return 0
}

# Function to monitor tests
monitor_tests() {
    log "📊 Monitoring test execution..."

    local timeout=300  # 5 minutes timeout
    local elapsed=0
    local last_count=0

    while [ $elapsed -lt $timeout ]; do
        if [ -f "$TELEMETRY_FILE" ]; then
            current_count=$(wc -l < "$TELEMETRY_FILE" 2>/dev/null || echo 0)

            if [ $current_count -gt $last_count ]; then
                new_entries=$((current_count - last_count))
                info "New telemetry entries: $new_entries (total: $current_count)"

                # Check for T3_Backfill progress
                t3_count=$(grep -c "T3_Backfill" "$TELEMETRY_FILE" 2>/dev/null || echo 0)
                if [ $t3_count -gt 0 ]; then
                    t3_success=$(grep "T3_Backfill" "$TELEMETRY_FILE" | grep -v '"itemsReturned":0' | wc -l)
                    info "T3_Backfill progress: $t3_success/$t3_count successful attempts"
                fi

                last_count=$current_count
            fi
        fi

        # Check if test report is complete
        if [ -f "$REPORT_FILE" ]; then
            log "✅ Test report generated - tests complete!"
            return 0
        fi

        sleep 2
        elapsed=$((elapsed + 2))
    done

    error "Tests timed out after $timeout seconds"
    return 1
}

# Function to analyze results
analyze_results() {
    log "📈 Analyzing test results..."

    if [ ! -f "$REPORT_FILE" ]; then
        error "No test report found!"
        return 1
    fi

    # Parse and display results
    python3 << 'EOF'
import json
import sys

# Load report
with open("$HOME/Library/Containers/eworthing.Tiercade/Data/tmp/tiercade_acceptance_test_report.json") as f:
    report = json.load(f)

print("\n" + "="*60)
print("TEST RESULTS SUMMARY")
print("="*60)

# Overall results
print(f"\nOverall: {report.get('passed', 0)}/{report.get('totalTests', 0)} tests passed")
print(f"Duration: {report.get('duration', 0):.2f} seconds")

# T3_Backfill specific
for test in report.get('testResults', []):
    if test.get('testId') == 'T3_Backfill':
        print("\n📊 T3_Backfill Results:")
        print(f"  Pass@N Rate: {test.get('passAtN', 0):.2%}")
        print(f"  Duplication Rate: {test.get('duplicationRate', 0):.1%}")
        print(f"  Status: {test.get('status', 'unknown')}")

        # Check if we met the target
        pass_n = test.get('passAtN', 0)
        if pass_n >= 0.6:
            print(f"  ✅ PASSED: Achieved {pass_n:.2%} (target ≥60%)")
        else:
            print(f"  ❌ FAILED: Only achieved {pass_n:.2%} (target ≥60%)")

# Analyze telemetry for more details
print("\n" + "="*60)
print("DETAILED TELEMETRY ANALYSIS")
print("="*60)

import os
telemetry_file = os.path.expanduser("~/Library/Containers/eworthing.Tiercade/Data/tmp/unique_list_runs.jsonl")

if os.path.exists(telemetry_file):
    t3_data = []
    with open(telemetry_file) as f:
        for line in f:
            if line.strip():
                try:
                    d = json.loads(line)
                    if d.get("testId") == "T3_Backfill":
                        t3_data.append(d)
                except:
                    pass

    if t3_data:
        # Success rate by method
        methods = {}
        for d in t3_data:
            method = d.get("sampling", "unknown")
            if method not in methods:
                methods[method] = {"success": 0, "total": 0}
            methods[method]["total"] += 1
            if d.get("itemsReturned", 0) > 0:
                methods[method]["success"] += 1

        print("\nSuccess rate by sampling method:")
        for method, stats in methods.items():
            rate = stats["success"] / stats["total"] * 100 if stats["total"] > 0 else 0
            print(f"  {method}: {rate:.1f}% ({stats['success']}/{stats['total']})")

        # Average items returned
        successful = [d for d in t3_data if d.get("itemsReturned", 0) > 0]
        if successful:
            avg_items = sum(d.get("itemsReturned", 0) for d in successful) / len(successful)
            print(f"\nAverage items when successful: {avg_items:.1f} (target: 50)")
EOF

    # Check debug logs
    debug_count=$(ls -1 "$DEBUG_DIR" 2>/dev/null | wc -l || echo 0)
    if [ $debug_count -gt 0 ]; then
        log "📝 Found $debug_count debug log files in $DEBUG_DIR"

        # Show a sample debug file
        sample=$(ls -1 "$DEBUG_DIR"/*.json 2>/dev/null | head -1)
        if [ -n "$sample" ]; then
            info "Sample debug file: $sample"
        fi
    else
        info "No debug logs found (may need to check logging implementation)"
    fi

    return 0
}

# Main execution
main() {
    log "🎯 Starting Automated Test Runner"
    log "Log file: $LOG_FILE"
    echo ""

    # Step 1: Cleanup
    cleanup

    # Step 2: Build
    if ! build_app; then
        error "Build failed - exiting"
        exit 1
    fi

    # Step 3: Launch tests
    if ! launch_tests; then
        error "Failed to launch tests - exiting"
        exit 1
    fi

    # Step 4: Monitor execution
    if ! monitor_tests; then
        error "Test monitoring failed or timed out"
        killall Tiercade 2>/dev/null || true
        exit 1
    fi

    # Step 5: Analyze results
    analyze_results

    # Cleanup
    killall Tiercade 2>/dev/null || true

    log ""
    log "✅ Test run complete!"
    log "Results saved to: $LOG_FILE"
    log "Debug logs in: $DEBUG_DIR"
    log "Telemetry in: $TELEMETRY_FILE"
}

# Handle command-line arguments
case "$1" in
    --help)
        echo "Usage: $0 [options]"
        echo "Options:"
        echo "  --help          Show this help"
        echo "  --no-build      Skip the build step"
        echo "  --keep-data     Don't clean up old test data"
        echo "  --timeout N     Set timeout in seconds (default: 300)"
        exit 0
        ;;
    --no-build)
        NO_BUILD=1
        ;;
    --keep-data)
        KEEP_DATA=1
        ;;
esac

# Run the tests
main