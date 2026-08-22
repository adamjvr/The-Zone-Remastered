#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

die() { print -u2 "ERROR: $*"; exit 1; }

echo "=== Milestone 0.6.2 consistency repair verification ==="

# The 0.6.1 failure was caused by implementation/tests from 0.6 being paired
# with older public/recovered headers. Verify the complete API set before build.
grep -q 'float zone_game_player_max_speed' ZoneCore/include/zone_core.h || die "zone_core.h is stale"
grep -q 'zone_game_debug_trigger_mother_defense' ZoneCore/include/zone_core.h || die "zone_core.h lacks 0.6 enemy-life API"
grep -q 'tz_initial_player_max_speed' ZoneCore/Recovered/include/thezone_decomp.h || die "thezone_decomp.h lacks 0.5 progression API"
grep -q 'tz_mother_should_launch_defenders' ZoneCore/Recovered/include/thezone_decomp.h || die "thezone_decomp.h lacks 0.6 Mother Base API"
grep -q 'tz_enemy_chase_interval' ZoneCore/Recovered/include/thezone_decomp.h || die "thezone_decomp.h lacks 0.6 enemy AI API"
grep -q 'float tz_initial_player_max_speed' ZoneCore/Recovered/src/objects.c || die "objects.c lacks progression implementation"
grep -q 'bool tz_mother_should_launch_defenders' ZoneCore/Recovered/src/ai.c || die "ai.c lacks Mother Base implementation"

# 0.6.1 bug fixes must remain present.
grep -q 'o->type != TZ_TYPE_MOTH && o->type != TZ_TYPE_BASE' ZoneCore/src/zone_core.c || die "Mother Base/HQ frame-stability fix missing"
grep -q 'private var pausePulse = false' Shared/ZoneInputRouter.swift || die "pause pulse fix missing"
grep -q 'menuDebounceSeconds: TimeInterval = 0.20' Shared/ZoneControllerManager.swift || die "controller pause debounce missing"
grep -q 'if !event.isARepeat' Shared/ZoneMetalView.swift || die "keyboard repeat suppression missing"

./Tools/test-zonecore.sh

if command -v swiftc >/dev/null 2>&1; then
  swiftc -parse \
    Shared/ZoneInputRouter.swift \
    Shared/ZoneControllerManager.swift \
    Shared/ZoneMetalView.swift \
    Shared/ZoneGameHost.swift \
    Shared/ZoneContentView.swift
  echo "Swift syntax parse: PASS"
else
  echo "swiftc unavailable; Swift syntax parse skipped"
fi

if [[ -x Tools/verify-native-targets.command ]]; then
  ./Tools/verify-native-targets.command
fi

echo "0.6/0.6.1 header + implementation consistency: PASS"
echo "Milestone 0.6.2 repair verification: PASS"
