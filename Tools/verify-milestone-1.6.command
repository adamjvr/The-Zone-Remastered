#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

# Milestone 1.6 intentionally accepts any commit SHA whose committed tree is
# the accepted Milestone 1.5 content. This lets 1.5 be committed locally with
# the user's normal SHA while still preventing application over 1.4/other work.
check_head_hash() {
  local path="$1"
  local expected="$2"
  local actual
  actual="$(git show "HEAD:${path}" 2>/dev/null | shasum -a 256 | awk '{print $1}')" || true
  if [[ -z "$actual" || "$actual" != "$expected" ]]; then
    echo "ERROR: committed base is not accepted Milestone 1.5: $path"
    echo "Expected: $expected"
    echo "Actual:   ${actual:-missing}"
    echo "Commit/push the accepted Milestone 1.5 tree before applying 1.6."
    exit 1
  fi
}

check_head_hash ZoneCore/src/zone_core.c 11a3d03d418088246a5dbd5544ff6fa66d3c74db5cf21543d5621876127d0e4e
check_head_hash ZoneCore/include/zone_core.h a81ccc9793120ed58c257bd2273164bbdde2a7af57a92c05f4c0fc3404729afd
check_head_hash ZoneCore/tests/test_zone_core.c 1f90a22a8be8624bcdf1a8712d34536988e29b34307038e0a723697f0add6591
check_head_hash Shared/ZoneGameHost.swift 6ff9d81d2338fde5acc3dd9b9bc2b30b2969abec0a9811c43f9069bb4f5a6083

if ! git show HEAD:README.md | grep -q 'Engineering Milestone 1.5'; then
  echo "ERROR: committed README is not Milestone 1.5. Commit 1.5 first."
  exit 1
fi

if [[ ! -f FILES.sha256 ]]; then
  echo "ERROR: FILES.sha256 missing."
  exit 1
fi
shasum -a 256 -c FILES.sha256

echo "[1/7] C syntax"
clang -std=c11 -Wall -Wextra -Werror -fsyntax-only \
  -IZoneCore/include -IZoneCore/src -IZoneCore/Recovered/include \
  ZoneCore/src/zone_core.c
clang -std=c11 -Wall -Wextra -Werror -fsyntax-only \
  -IZoneCore/include -IZoneCore/src -IZoneCore/Recovered/include \
  ZoneCore/tests/test_zone_core.c

echo "[2/7] Shared 80-object semantics"
grep -q '#define ZONE_CLASSIC_OBJECT_CAP 80' ZoneCore/src/zone_core.c
grep -q 'classic_object_slots_used' ZoneCore/src/zone_core.c
grep -q 'zone_game_debug_classic_object_capacity' ZoneCore/include/zone_core.h
grep -q 'test_shared_classic_object_capacity' ZoneCore/tests/test_zone_core.c

echo "[3/7] Base impact parity"
grep -q 'o->mother_motion_state = 0;' ZoneCore/src/zone_core.c
grep -q 'g->player_hit_flash_ticks = 1;' ZoneCore/src/zone_core.c
grep -q 'test_mother_base_collision_state_feedback' ZoneCore/tests/test_zone_core.c

echo "[4/7] Accepted 1.5 host/render/audio untouched"
for path in Shared/ZoneGameHost.swift Shared/ZoneRenderer.swift Shared/ZoneAudioEngine.swift; do
  if ! git diff --quiet HEAD -- "$path"; then
    echo "ERROR: Milestone 1.6 must not modify $path"
    git diff -- "$path"
    exit 1
  fi
done

echo "[5/7] Full ZoneCore regressions"
./Tools/test-zonecore.sh

echo "[6/7] Timebase/native target regressions"
./Tools/test-zone-timebase.command
./Tools/verify-native-targets.command

echo "[7/7] Patch hygiene"
git diff --check

echo "Milestone 1.6 verification: PASS"
