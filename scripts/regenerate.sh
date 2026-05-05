#!/usr/bin/env bash
# scripts/regenerate.sh
# Regeneruj PolskiWhisper.xcodeproj po zmianach w project.yml.
# Użyj gdy: dodajesz nową dependency, zmieniasz target, dodajesz folder.

set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v xcodegen &> /dev/null; then
    echo "Error: xcodegen not installed. Run scripts/setup.sh first."
    exit 1
fi

echo "Regenerating PolskiWhisper.xcodeproj from project.yml..."
xcodegen generate

echo "Done. Open in Xcode: open PolskiWhisper.xcodeproj"
