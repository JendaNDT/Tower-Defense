#!/bin/bash
cd "$(dirname "$0")"
if command -v python3 >/dev/null 2>&1; then
  python3 spustit.py
else
  echo "Pro spuštění hry je potřeba Python 3: https://www.python.org/downloads/"
  read -n 1 -s -r -p "Stiskni libovolnou klávesu…"
fi
