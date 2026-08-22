#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

echo "=== Milestone 0.6.1 bugfix verification ==="

grep -q 'o->type != TZ_TYPE_MOTH && o->type != TZ_TYPE_BASE' ZoneCore/src/zone_core.c
grep -q 'test_mother_base_frame_is_stable' ZoneCore/tests/test_zone_core.c
grep -q 'private var pausePulse = false' Shared/ZoneInputRouter.swift
grep -q 'menuDebounceSeconds: TimeInterval = 0.20' Shared/ZoneControllerManager.swift
grep -q 'if !event.isARepeat' Shared/ZoneMetalView.swift

./Tools/test-zonecore.sh

if command -v swiftc >/dev/null 2>&1; then
  swiftc -parse \
    Shared/ZoneInputRouter.swift \
    Shared/ZoneControllerManager.swift \
    Shared/ZoneMetalView.swift
  echo "Swift syntax parse: PASS"
else
  echo "swiftc unavailable; Swift syntax parse skipped"
fi

echo "Pause edge/debounce wiring: PASS"
echo "Mother Base/HQ frame stability wiring: PASS"
echo "Milestone 0.6.1 verification: PASS"
