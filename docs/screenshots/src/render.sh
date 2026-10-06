#!/usr/bin/env bash
# Render the README illustrations with headless Chrome (Brave as fallback).
# Usage: docs/screenshots/src/render.sh
# Output: docs/screenshots/hero.png and docs/screenshots/phases-overview.png at 2x.
set -euo pipefail

SRC="$(cd "$(dirname "$0")" && pwd)"
OUT="$(dirname "$SRC")"

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || CHROME="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
[ -x "$CHROME" ] || { echo "No Chrome or Brave found" >&2; exit 1; }

# name  width,height (CSS px; the page width plus the .wrap padding)
render() {
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars \
    --force-device-scale-factor=2 --window-size="$2" \
    --screenshot="$OUT/$1.png" "file://$SRC/$1.html" 2>/dev/null
  echo "rendered $OUT/$1.png"
}

render hero            1100,639
render phases-overview 1300,800
