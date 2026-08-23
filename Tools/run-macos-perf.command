#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

PRODUCTS="build/DerivedData/Build/Products/Debug"
if [[ ! -d "$PRODUCTS" ]]; then
  echo "No Debug build found. Building macOS target first..."
  ./Tools/build-macos.command
fi

APP="$(find "$PRODUCTS" -maxdepth 2 -type d -name '*.app' -print | head -n 1)"
if [[ -z "$APP" || ! -d "$APP" ]]; then
  echo "ERROR: could not locate built .app under $PRODUCTS"
  exit 1
fi

PLIST="$APP/Contents/Info.plist"
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$PLIST")"
BIN="$APP/Contents/MacOS/$EXECUTABLE"
if [[ ! -x "$BIN" ]]; then
  echo "ERROR: app executable not found: $BIN"
  exit 1
fi

mkdir -p build/perf-logs
STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="build/perf-logs/zone-perf-${STAMP}.log"

echo "Launching: $APP"
echo "Diagnostics log: $LOG"
echo "Play until you reproduce the hitch or clear a zone, then quit normally."
echo

ZONE_PERF_DIAGNOSTICS=1 "$BIN" 2>&1 | tee "$LOG"

echo
echo "Saved: $LOG"
echo
./Tools/summarize-macos-perf.command "$LOG" || true

echo
echo "Useful raw filter:"
echo "  grep -E 'host-detail|slow-trigger|frame-gap|slow-step|slow-cpu-frame|texture-miss|voice-steal|sprite-preload' '$LOG'"
