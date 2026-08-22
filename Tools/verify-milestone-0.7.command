#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

printf '%s\n' '=== Milestone 0.7 verification ==='

./Tools/test-zonecore.sh

grep -q 'ZONE_FIRE_SPRITE 152' ZoneCore/src/zone_core.c
grep -q 'tz_enemy_projectile_speed' ZoneCore/Recovered/src/ai.c
grep -q 'populate_fixed_wave' ZoneCore/src/zone_core.c
grep -q 'TheZone.KeyboardBindings.v1' Shared/ZoneInputRouter.swift
grep -q 'Keyboard Controls' README.md
grep -q 'Milestone 0.7' Docs/ROADMAP.md
grep -q 'Milestone 0.7' Docs/MILESTONE-0.7.md

if command -v xcrun >/dev/null 2>&1; then
  xcrun swiftc -parse \
    Shared/ZoneInputRouter.swift \
    Shared/ZoneMetalView.swift \
    Shared/ZoneContentView.swift
  printf '%s\n' 'Swift syntax parse: PASS (xcrun swiftc)'
elif command -v swiftc >/dev/null 2>&1; then
  swiftc -parse \
    Shared/ZoneInputRouter.swift \
    Shared/ZoneMetalView.swift \
    Shared/ZoneContentView.swift
  printf '%s\n' 'Swift syntax parse: PASS'
else
  printf '%s\n' 'Swift syntax parse: SKIPPED (swiftc unavailable)'
fi

if command -v xcodebuild >/dev/null 2>&1 && [ -x Tools/verify-native-targets.command ]; then
  ./Tools/verify-native-targets.command
fi

printf '%s\n' 'Milestone 0.7 verification: PASS'
