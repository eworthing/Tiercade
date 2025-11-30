#!/bin/bash
# Claude Code PostToolUse hook: format and lint Swift files after Edit/Write
# This runs automatically after every file modification by Claude Code

set -e

# Read the PostToolUse input from stdin
input=$(cat)

# Extract file_path using jq (or fallback to grep if jq unavailable)
if command -v jq &>/dev/null; then
  file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')
else
  file_path=$(echo "$input" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*: *"\([^"]*\)".*/\1/')
fi

# Exit if no file path
[ -z "$file_path" ] && exit 0

# Only process Swift files
if [[ "$file_path" == *.swift ]] && [ -f "$file_path" ]; then
  SWIFTFORMAT=$(which swiftformat 2>/dev/null || echo "/opt/homebrew/bin/swiftformat")
  SWIFTLINT=$(which swiftlint 2>/dev/null || echo "/opt/homebrew/bin/swiftlint")

  # Run SwiftFormat (auto-fix formatting)
  if [ -x "$SWIFTFORMAT" ]; then
    "$SWIFTFORMAT" "$file_path" --quiet 2>/dev/null || true
  fi

  # Run SwiftLint with auto-fix (corrects fixable issues)
  if [ -x "$SWIFTLINT" ]; then
    "$SWIFTLINT" lint --fix --path "$file_path" --quiet 2>/dev/null || true
  fi
fi

exit 0
