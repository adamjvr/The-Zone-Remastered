#!/bin/zsh
set -euo pipefail
ROOT="${0:A:h:h}"
cd "$ROOT"

echo "=== Milestone 0.8 verification ==="
chmod +x Tools/test-zonecore.sh
./Tools/test-zonecore.sh

if command -v swiftc >/dev/null 2>&1; then
  swiftc -parse Shared/*.swift macOS/*.swift iPadOS/*.swift
  echo "Swift syntax parse: PASS"
else
  echo "swiftc unavailable: Swift syntax parse skipped"
fi

grep -q 'float flash;' ZoneCore/include/zone_core.h
grep -q 'ZONE_AUDIO_HIT = 4' ZoneCore/include/zone_core.h
grep -q 'tz_hq_defender_active_cap' ZoneCore/Recovered/src/ai.c
grep -q 'Mother Base 40-hit damage continuity' ZoneCore/tests/test_zone_core.c
grep -q 'constant float &flash' Shared/ZoneShaders.metal
grep -q 'Milestone 0.8' Docs/ROADMAP.md

echo "0.8 base-damage feedback/HQ integration checks: PASS"

if [[ -x Tools/verify-native-targets.command ]]; then
  ./Tools/verify-native-targets.command
fi
