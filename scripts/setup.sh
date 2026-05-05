#!/usr/bin/env bash
# scripts/setup.sh
# Setup PolskiWhisper dev environment - jednorazowy bootstrap dla nowych klonów repo.
# Idempotent (można uruchomić wielokrotnie bezpiecznie).

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== PolskiWhisper - setup środowiska deweloperskiego ===${NC}\n"

# ============================================================
# 1. Sprawdź wymagania systemowe
# ============================================================

echo -e "${BLUE}[1/4] Sprawdzanie wymagań systemowych...${NC}"

# macOS version
macos_version=$(sw_vers -productVersion)
required_major=14
actual_major=$(echo "$macos_version" | cut -d. -f1)

if [ "$actual_major" -lt "$required_major" ]; then
    echo -e "${RED}✗ macOS $macos_version - wymagane minimum 14 (Sonoma)${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} macOS $macos_version"

# Apple Silicon
arch=$(uname -m)
if [ "$arch" != "arm64" ]; then
    echo -e "${RED}✗ Architektura $arch - PolskiWhisper wymaga Apple Silicon (arm64)${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Apple Silicon ($arch)"

# Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}✗ xcodebuild nie znalezione${NC}"
    echo -e "${YELLOW}  Pobierz Xcode z Mac App Store: https://apps.apple.com/us/app/xcode/id497799835${NC}"
    echo -e "${YELLOW}  Po instalacji uruchom: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer${NC}"
    exit 1
fi

xcode_check=$(xcodebuild -version 2>&1 | head -1)
if [[ "$xcode_check" == *"requires Xcode"* ]]; then
    echo -e "${RED}✗ Xcode nie jest aktywne (tylko Command Line Tools)${NC}"
    echo -e "${YELLOW}  Pobierz pełne Xcode z Mac App Store, potem:${NC}"
    echo -e "${YELLOW}  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} $xcode_check"

# Homebrew (dla xcodegen)
if ! command -v brew &> /dev/null; then
    echo -e "${RED}✗ Homebrew nie znalezione${NC}"
    echo -e "${YELLOW}  Instaluj: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\"${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Homebrew $(brew --version | head -1 | cut -d' ' -f2)"

# ============================================================
# 2. Zainstaluj xcodegen jeśli potrzeba
# ============================================================

echo -e "\n${BLUE}[2/4] Sprawdzanie XcodeGen...${NC}"

if ! command -v xcodegen &> /dev/null; then
    echo -e "${YELLOW}  XcodeGen nie znalezione - instaluję...${NC}"
    brew install xcodegen
fi
echo -e "${GREEN}✓${NC} xcodegen $(xcodegen --version | cut -d' ' -f2)"

# ============================================================
# 3. Generuj projekt Xcode
# ============================================================

echo -e "\n${BLUE}[3/4] Generuję projekt Xcode z project.yml...${NC}"

cd "$(dirname "$0")/.."
xcodegen generate

if [ ! -d "PolskiWhisper.xcodeproj" ]; then
    echo -e "${RED}✗ Generacja .xcodeproj się nie powiodła${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} PolskiWhisper.xcodeproj wygenerowane"

# ============================================================
# 4. Resolve Swift Packages (downloads dependencies)
# ============================================================

echo -e "\n${BLUE}[4/4] Pobieram zależności Swift Package Manager...${NC}"
echo -e "${YELLOW}  (pierwszy run może zająć 1-3 min)${NC}"

xcodebuild -resolvePackageDependencies \
    -project PolskiWhisper.xcodeproj \
    -scheme PolskiWhisper \
    -quiet || {
    echo -e "${RED}✗ Resolve packages się nie powiódł${NC}"
    echo -e "${YELLOW}  Spróbuj otworzyć projekt w Xcode i poczekać na automatyczny resolve${NC}"
    exit 1
}
echo -e "${GREEN}✓${NC} Zależności pobrane"

# ============================================================
# Done
# ============================================================

echo -e "\n${GREEN}=== Setup zakończony! ===${NC}\n"
echo -e "Następne kroki:"
echo -e "  ${BLUE}open PolskiWhisper.xcodeproj${NC}     - otwórz w Xcode"
echo -e "  ${BLUE}./scripts/build.sh${NC}                - build z command line"
echo -e "  ${BLUE}./scripts/regenerate.sh${NC}           - regeneruj projekt po zmianach w project.yml"
echo ""
