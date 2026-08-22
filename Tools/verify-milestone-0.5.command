#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

./Tools/test-zonecore.sh

grep -q 'tz_initial_player_max_speed' ZoneCore/Recovered/src/objects.c
grep -q 'return 25.0f' ZoneCore/Recovered/src/objects.c
grep -q 'tz_velocity_module_apply' ZoneCore/src/zone_core.c
grep -q 'tz_ammo_loader_apply' ZoneCore/src/zone_core.c
grep -q 'spawn_asteroid_payload' ZoneCore/src/zone_core.c
grep -q 'fragment_big_rock' ZoneCore/src/zone_core.c
grep -q 'begin_player_death' ZoneCore/src/zone_core.c
grep -q 'maximum_speed' ZoneCore/include/zone_core.h
grep -q '0x17908' Docs/MILESTONE-0.5.md
grep -q '0x19718' Docs/MILESTONE-0.5.md

if command -v swiftc >/dev/null 2>&1; then
  swiftc -frontend -parse Shared/ZoneGameHost.swift Shared/ZoneContentView.swift >/dev/null
  print "Swift syntax parse: PASS"
fi

print "Milestone 0.5 destruction/progression verification: PASS"
