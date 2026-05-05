#!/usr/bin/env bash
# scripts/install.sh
# Buduje PolskiWhisper i instaluje do /Applications/.
# Po tym aplikację można uruchamiać z Findera/Spotlight/Docka jak każdą inną macOS app,
# bez potrzeby otwierania Xcode.
#
# Workflow:
#   1. ./scripts/install.sh                    # build + copy do /Applications
#   2. open /Applications/PolskiWhisper.app    # uruchom (lub z Findera)
#   3. (raz) Dodaj /Applications/PolskiWhisper.app do Dostępność + Mikrofon
#   4. Settings → Ogólne → włącz autostart - od teraz startuje przy logowaniu
#
# Po update kodu: ponownie ./scripts/install.sh (signature stable z Personal Team
# więc TCC permissions zachowane).

set -euo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

cd "$(dirname "$0")/.."

echo -e "${BLUE}=== PolskiWhisper - install do /Applications ===${NC}\n"

# 1. Sprawdzenia
if [ ! -d "PolskiWhisper.xcodeproj" ]; then
    echo -e "${RED}Brak PolskiWhisper.xcodeproj - uruchom najpierw ./scripts/setup.sh${NC}"
    exit 1
fi

# 2. Build Release configuration (mniejszy, optimized, bez DEBUG)
echo -e "${BLUE}[1/3] Building Release configuration...${NC}"
xcodebuild \
    -project PolskiWhisper.xcodeproj \
    -scheme PolskiWhisper \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    build 2>&1 | grep -E "error:|warning:|BUILD" | tail -10

# 3. Znajdź zbudowany .app
APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData -name "PolskiWhisper.app" \
    -path "*Build/Products/Release/*" -not -path "*Index.noindex*" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Nie znaleziono zbudowanej PolskiWhisper.app w DerivedData${NC}"
    echo -e "${YELLOW}Otwórz Xcode, wybierz scheme PolskiWhisper, kliknij Build (Cmd+B) i spróbuj ponownie${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} App zbudowany: $APP_PATH"

# 4. Kopiowanie do /Applications/
echo -e "\n${BLUE}[2/3] Kopiuję do /Applications/...${NC}"
DESTINATION="/Applications/PolskiWhisper.app"

if [ -d "$DESTINATION" ]; then
    # Sprawdź czy aplikacja jest uruchomiona
    if pgrep -x "PolskiWhisper" > /dev/null; then
        echo -e "${YELLOW}  PolskiWhisper jest uruchomiona - zatrzymuję...${NC}"
        pkill -x "PolskiWhisper" || true
        sleep 1
    fi
    echo -e "${YELLOW}  Usuwam poprzednią wersję z /Applications/...${NC}"
    rm -rf "$DESTINATION"
fi

cp -R "$APP_PATH" "$DESTINATION"
echo -e "${GREEN}✓${NC} Skopiowano do $DESTINATION"

# 5. Touch żeby Launch Services odświeżyło
touch "$DESTINATION"

# 6. Done - instrukcje
echo -e "\n${BLUE}[3/3] Gotowe!${NC}\n"
echo -e "Następne kroki:"
echo -e ""
echo -e "  ${BLUE}Pierwsze uruchomienie:${NC}"
echo -e "    open /Applications/PolskiWhisper.app"
echo -e "    (lub kliknij dwa razy w Finderze)"
echo -e ""
echo -e "  ${BLUE}Po pierwszym uruchomieniu (raz):${NC}"
echo -e "    1. Ustawienia systemu → Prywatność i ochrona → Dostępność"
echo -e "       Dodaj /Applications/PolskiWhisper.app i włącz przełącznik"
echo -e "    2. Mikrofon - prompt pojawi się sam, kliknij Zezwól"
echo -e "    3. Cmd+, w aplikacji → Ogólne → włącz autostart przy logowaniu"
echo -e ""
echo -e "  ${BLUE}Test:${NC}"
echo -e "    Otwórz Notatki → kliknij w pole → tap lewy Option → mów → tap"
echo -e ""
echo -e "  ${BLUE}Po update kodu:${NC}"
echo -e "    ./scripts/install.sh           # rebuild + reinstall"
echo -e ""
