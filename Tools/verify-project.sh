#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
plutil -lint "$ROOT/TheZoneRemastered.xcodeproj/project.pbxproj"
plutil -lint "$ROOT/iPadOS/Info.plist"
"$ROOT/Tools/test-zonecore.sh"
if command -v swiftc >/dev/null 2>&1; then
  swiftc -parse "$ROOT"/Shared/*.swift "$ROOT"/macOS/*.swift "$ROOT"/iPadOS/*.swift
fi
count=$(find "$ROOT/Resources/Sprites" -type f -name 'Spri_*.png' | wc -l | tr -d ' ')
[ "$count" = "651" ] || { echo "expected 651 sprites, got $count" >&2; exit 1; }
sounds=$(find "$ROOT/Resources/Sounds" -type f -name 'snd_*.wav' | wc -l | tr -d ' ')
[ "$sounds" = "36" ] || { echo "expected 36 sounds, got $sounds" >&2; exit 1; }
echo "Project static verification: PASS (651 sprites, 36 sounds)"
