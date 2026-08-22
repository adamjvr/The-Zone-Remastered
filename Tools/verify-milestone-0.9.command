#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"

echo "=== Milestone 0.9 verification ==="
chmod +x Tools/test-zonecore.sh
./Tools/test-zonecore.sh

grep -q 'tz_mother_motion_state_from_random_word' ZoneCore/Recovered/src/ai.c
grep -q 'tz_mother_direct_speed' ZoneCore/Recovered/src/ai.c
grep -q 'tz_hq_fire_interval' ZoneCore/Recovered/src/ai.c
grep -q 'mobile_mothers_left = preset->mobile_moth_quota' ZoneCore/src/zone_core.c
grep -q 'activate_mobile_mother_after_player_kill' ZoneCore/src/zone_core.c
grep -q 'update_hq_fire' ZoneCore/src/zone_core.c
grep -q 'Fixed-wave mobile Mother +84 quota / kill activation: PASS' ZoneCore/tests/test_zone_core.c
grep -q 'Mother Base states 0/1/2 live movement: PASS' ZoneCore/tests/test_zone_core.c
grep -q 'Headquarters 15-tick independent fire cadence: PASS' ZoneCore/tests/test_zone_core.c
grep -q 'Milestone 0.9' Docs/ROADMAP.md

echo "0.9 Mother motion / HQ fire integration checks: PASS"

if command -v swiftc >/dev/null 2>&1; then
  swiftc -parse Shared/*.swift macOS/*.swift iPadOS/*.swift
  echo "Swift syntax parse: PASS"
else
  echo "swiftc unavailable: Swift syntax parse skipped"
fi

if [[ -x Tools/verify-native-targets.command ]]; then
  ./Tools/verify-native-targets.command
fi
