#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

BASE="a4b61fa63db0eddf953829d33b183b358da651e0"

fail() {
  echo "ERROR: $*"
  exit 1
}

[[ -d .git ]] || fail "run from the The-Zone-Remastered repository root"
[[ "$(git rev-parse HEAD)" == "$BASE" ]] || fail "Milestone 1.8 requires committed Milestone 1.7 at $BASE"

shasum -a 256 -c FILES.sha256

# Product-shell work must not reopen the accepted runtime architecture.
protected=(
  ZoneCore
  Shared/ZoneGameHost.swift
  Shared/ZoneMetalView.swift
  Shared/ZoneRenderer.swift
  Shared/ZoneAudioEngine.swift
  Shared/ZoneInputRouter.swift
  Shared/ZoneControllerManager.swift
  Shared/ZoneTouchControls.swift
  project.yml
  TheZoneRemastered.xcodeproj
)
for path in $protected; do
  if ! git diff --quiet "$BASE" -- "$path"; then
    fail "Milestone 1.8 unexpectedly changes protected runtime path: $path"
  fi
done

grep -q 'struct ZoneAppShell: View' Shared/ZoneContentView.swift || fail "ZoneAppShell missing"
grep -q 'ZONE_BOOT_DIRECT' Shared/ZoneContentView.swift || fail "direct developer boot missing"
grep -q 'Button("NEW GAME")' Shared/ZoneContentView.swift || fail "New Game menu action missing"
grep -q 'Button("PREFERENCES")' Shared/ZoneContentView.swift || fail "Preferences menu action missing"
grep -q 'Button("CREDITS")' Shared/ZoneContentView.swift || fail "Credits menu action missing"
grep -q 'Button("Title Screen")' Shared/ZoneContentView.swift || fail "macOS Return-to-Title action missing"
grep -q 'Button("TITLE SCREEN")' Shared/ZoneContentView.swift || fail "iPadOS Return-to-Title action missing"
grep -q 'String(format: "Spri_%05d", 1000 + frame)' Shared/ZoneContentView.swift || fail "recovered 48-frame title ship bank missing"
grep -q 'subdirectory: "Sprites"' Shared/ZoneContentView.swift || fail "title sprite bundle lookup missing"
grep -q 'ZoneFrontEnd.showHUD' Shared/ZoneContentView.swift || fail "persistent front-end preferences missing"
grep -q 'ZoneAppShell()' macOS/TheZoneMacApp.swift || fail "macOS app does not boot through ZoneAppShell"
grep -q 'ZoneAppShell()' iPadOS/TheZonePadApp.swift || fail "iPadOS app does not boot through ZoneAppShell"

[[ -f Resources/Sprites/Spri_01000.png ]] || fail "ship sprite Spri_01000.png missing"
[[ -f Resources/Sprites/Spri_01047.png ]] || fail "ship sprite Spri_01047.png missing"

grep -q 'Engineering Milestone 1.8' README.md || fail "README milestone heading not updated"
grep -q 'Milestone 1.8 — Native Front-End' README.md || fail "README 1.8 section missing"
grep -q 'Native Front-End & Title Screen' Docs/ROADMAP.md || fail "roadmap 1.8 section missing"

if command -v xcrun >/dev/null 2>&1; then
  xcrun swiftc -parse \
    Shared/ZoneContentView.swift \
    macOS/TheZoneMacApp.swift \
    iPadOS/TheZonePadApp.swift
else
  echo "NOTE: xcrun unavailable; skipping Apple Swift parse in this environment."
fi

./Tools/test-zonecore.sh
./Tools/test-zone-timebase.command
./Tools/verify-native-targets.command

echo "Milestone 1.8 verification: PASS"
