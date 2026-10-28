#!/usr/bin/env bash
# Sestaví webovou verzi hry do složky docs/ (potřebuje nainstalovaný Godot 4.7 + exportní šablony pro web).
# Použití:  tools/build_web.sh [cesta/k/godot]
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${1:-${GODOT:-godot}}"
mkdir -p docs
"$GODOT" --headless --path . --import
"$GODOT" --headless --path . --export-release "Web" docs/index.html
echo "Hotovo: docs/index.html"
