#!/usr/bin/env bash
# scripts/build-dmg.sh
# Buduje PolskiWhisper Release configuration + tworzy DMG installer.
# Wymagane: stable signing setup (PolskiWhisper Self-Signed cert) - bez tego
# DMG się utworzy ale userzy zobaczą "unidentified developer" warning.
#
# Output: dist/PolskiWhisper-<version>.dmg

set -euo pipefail

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/.."

# Wersja z project.yml
VERSION=$(grep -E '^\s+MARKETING_VERSION:' project.yml | sed 's/.*"\(.*\)"/\1/')
DMG_NAME="PolskiWhisper-${VERSION}"
DMG_PATH="dist/${DMG_NAME}.dmg"
TEMP_DIR=$(mktemp -d)

echo -e "${BLUE}=== Build DMG installer dla PolskiWhisper v${VERSION} ===${NC}\n"

# 1. Build Release configuration
echo -e "${BLUE}[1/4] Build Release...${NC}"
xcodebuild \
    -project PolskiWhisper.xcodeproj \
    -scheme PolskiWhisper \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    build 2>&1 | grep -E "error:|BUILD" | tail -5

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "PolskiWhisper.app" \
    -path "*Build/Products/Release/*" -not -path "*Index.noindex*" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Brak zbudowanej PolskiWhisper.app w Release config${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} App: $APP_PATH"

# Verify code signature (codesign -dvvv pokazuje Authority, -dv nie)
SIGNATURE=$(codesign -dvvv "$APP_PATH" 2>&1 | grep "Authority=" | head -1 | sed 's/Authority=//' || echo "(unsigned/ad-hoc)")
echo -e "${GREEN}✓${NC} Signed by: ${SIGNATURE:-(unsigned)}"

# 2. Prepare DMG content folder
echo -e "\n${BLUE}[2/4] Przygotowanie zawartości DMG...${NC}"
DMG_CONTENT="$TEMP_DIR/dmg_content"
mkdir -p "$DMG_CONTENT"
cp -R "$APP_PATH" "$DMG_CONTENT/"

# Symlink do /Applications dla łatwego drag-and-drop install
ln -s /Applications "$DMG_CONTENT/Applications"
echo -e "${GREEN}✓${NC} DMG content gotowy"

# 3. Create DMG
echo -e "\n${BLUE}[3/4] Tworzenie DMG...${NC}"
mkdir -p dist/
rm -f "$DMG_PATH"

hdiutil create \
    -volname "PolskiWhisper" \
    -srcfolder "$DMG_CONTENT" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH" 2>&1 | tail -3

echo -e "${GREEN}✓${NC} DMG: $DMG_PATH"

# 4. Cleanup + info
echo -e "\n${BLUE}[4/4] Finalizing...${NC}"
rm -rf "$TEMP_DIR"

DMG_SIZE=$(du -h "$DMG_PATH" | cut -f1)
echo -e "${GREEN}✓${NC} Rozmiar: $DMG_SIZE"

echo -e "\n${GREEN}=== Gotowe! ===${NC}"
echo -e ""
echo -e "DMG installer: ${BLUE}$DMG_PATH${NC}"
echo -e ""
echo -e "Następne kroki:"
echo -e "  ${BLUE}open dist/${NC}                                       # otwórz folder z DMG"
echo -e "  ${BLUE}open $DMG_PATH${NC}                  # przetestuj sam"
echo -e ""
echo -e "Distribute przez GitHub Release (gh release create v${VERSION} $DMG_PATH)"
echo -e ""
echo -e "${YELLOW}UWAGA: bez Apple Developer ID, użytkownicy zobaczą 'unidentified developer'${NC}"
echo -e "${YELLOW}warning. Instrukcja ominięcia w docs/INSTALL.md.${NC}"
