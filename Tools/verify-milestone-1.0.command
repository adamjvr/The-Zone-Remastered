#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"

echo "=== Milestone 1.0 verification ==="
chmod +x Tools/test-zonecore.sh
./Tools/test-zonecore.sh

grep -q 'tz_rotor_orbit_radius' ZoneCore/Recovered/src/ai.c
grep -q 'tz_rotor_attack_radius_squared' ZoneCore/Recovered/src/ai.c
grep -q 'case TZ_TYPE_ROTO: return tz_signed_random_strict_window(random_word, 10000, 15000)' ZoneCore/Recovered/src/ai.c
grep -q 'update_rotor_ai' ZoneCore/src/zone_core.c
grep -q 'parent->rotor_slot = rotor_slot' ZoneCore/src/zone_core.c
grep -q 'destroyed_type == TZ_TYPE_ROTO' ZoneCore/src/zone_core.c
grep -q 'zone_game_debug_rotor_state' ZoneCore/include/zone_core.h
grep -q 'test_rotor_orbit_attack_return_live' ZoneCore/tests/test_zone_core.c
grep -q 'Recovered Rotor orbit/attack/return + wake/link/fire semantics: PASS' ZoneCore/tests/test_zone_core.c
grep -q 'Milestone 1.0' Docs/ROADMAP.md
grep -q 'Rotor (`roto`) — `0x15BC8..0x16124`' Docs/RE-ai_behavior.md

echo "1.0 Rotor orbit / attack / return integration checks: PASS"

if command -v swiftc >/dev/null 2>&1; then
  swiftc -parse Shared/*.swift macOS/*.swift iPadOS/*.swift
  echo "Swift syntax parse: PASS"
else
  echo "swiftc unavailable: Swift syntax parse skipped"
fi

if [[ -x Tools/verify-native-targets.command ]]; then
  ./Tools/verify-native-targets.command
fi
