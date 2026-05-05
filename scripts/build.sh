#!/usr/bin/env bash
# scripts/build.sh
# Build PolskiWhisper z command line (debug configuration).
# Useful dla CI lub szybkiego sprawdzenia czy kod się buduje bez otwierania Xcode.

set -euo pipefail

cd "$(dirname "$0")/.."

# Default config
CONFIG="${1:-Debug}"

if [ ! -d "PolskiWhisper.xcodeproj" ]; then
    echo "Error: PolskiWhisper.xcodeproj nie istnieje."
    echo "Uruchom najpierw: ./scripts/setup.sh lub ./scripts/regenerate.sh"
    exit 1
fi

echo "Building PolskiWhisper ($CONFIG)..."

# UWAGA: NIE używamy -derivedDataPath - SwiftPM wymaga modern build locations
# (default DerivedData). Xcode IDE i ten skrypt używają TEJ SAMEJ ścieżki:
# ~/Library/Developer/Xcode/DerivedData/PolskiWhisper-<hash>/Build/Products/<Config>/

xcodebuild \
    -project PolskiWhisper.xcodeproj \
    -scheme PolskiWhisper \
    -configuration "$CONFIG" \
    -destination 'platform=macOS,arch=arm64' \
    build

echo ""
echo "Build successful. App at:"
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "PolskiWhisper.app" -path "*Build/Products/$CONFIG/*" 2>/dev/null | head -1)
echo "  $APP_PATH"
echo ""
echo "Run with: open \"$APP_PATH\""
