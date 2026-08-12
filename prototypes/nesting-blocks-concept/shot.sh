#!/usr/bin/env bash
# PROTOTYPE - NOT FOR PRODUCTION
# Screenshots the prototype with headless Chrome/Edge (no install needed).
#
# Usage:
#   ./shot.sh                          -> shots/tray.png (level 1, empty tray)
#   ./shot.sh nest                     -> greens pre-nested into blues in the tray
#   ./shot.sh solved 2                 -> level 2 fully solved
#   ./shot.sh nest 1 hitbox            -> with the real-hitbox overlay on
#
# Scenarios come from SCENARIOS in prototype.html: tray | nest | solved
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIO="${1:-tray}"
LEVEL="${2:-1}"
HITBOX="${3:-}"

BROWSER=""
for cand in \
  "/c/Program Files/Google/Chrome/Application/chrome.exe" \
  "/c/Program Files (x86)/Google/Chrome/Application/chrome.exe" \
  "/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe" \
  "/c/Program Files/Microsoft/Edge/Application/msedge.exe"
do
  [ -x "$cand" ] && BROWSER="$cand" && break
done
[ -n "$BROWSER" ] || { echo "No Chrome/Edge found" >&2; exit 1; }

QUERY="scenario=${SCENARIO}&level=${LEVEL}"
NAME="${SCENARIO}-l${LEVEL}"
if [ "$HITBOX" = "hitbox" ]; then QUERY="${QUERY}&hitbox=1"; NAME="${NAME}-hitbox"; fi

mkdir -p "$DIR/shots"
OUT="$DIR/shots/${NAME}.png"

# Windows paths need the file:///C:/... form for the browser.
WINDIR="$(cd "$DIR" && pwd -W 2>/dev/null || echo "$DIR")"

# Portrait phone: 540x960 CSS px at 2x = a 1080x1920 capture.
"$BROWSER" --headless=new --disable-gpu --hide-scrollbars \
  --virtual-time-budget=1500 \
  --screenshot="$(cygpath -w "$OUT" 2>/dev/null || echo "$OUT")" \
  --window-size=540,960 --force-device-scale-factor=2 \
  "file:///${WINDIR}/prototype.html?${QUERY}" >/dev/null 2>&1

echo "$OUT"
