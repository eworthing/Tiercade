#!/bin/bash
# Install git hooks for Tiercade
# Run once after cloning: ./scripts/install-hooks.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo "Installing git hooks..."

# Install pre-commit hook
cp "$SCRIPT_DIR/pre-commit" "$REPO_ROOT/.git/hooks/pre-commit"
chmod +x "$REPO_ROOT/.git/hooks/pre-commit"

echo "✓ Pre-commit hook installed"
echo ""
echo "The hook will automatically:"
echo "  • Run SwiftFormat on staged Swift files"
echo "  • Check SwiftLint for errors (warnings allowed)"
echo "  • Block commits with lint errors"
