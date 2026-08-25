#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

check_head_hash() {
  local path="$1" expected="$2" actual
  actual="$(git show "HEAD:${path}" 2>/dev/null | shasum -a 256 | awk '{print $1}')" || true
  if [[ -z "$actual" || "$actual" != "$expected" ]]; then
    echo "ERROR: committed base is not the accepted Milestone 1.6 tree: $path"
    echo "Expected: $expected"
    echo "Actual:   ${actual:-missing}"
    echo "Commit/push the accepted Milestone 1.6 tree before applying 1.7."
    exit 1
  fi
}

check_head_hash ZoneCore/src/zone_core.c a409307b55ddc5df6721f09bcfa31b1c1685d4ae3111d5db12a0354298c9b50d
check_head_hash ZoneCore/include/zone_core.h a856077435ef991c20d97b07bebb23cfae285c7e634d9753fcbed42418b9d358
check_head_hash ZoneCore/tests/test_zone_core.c 42890ff9c2f6524264df4182ae97311adbb90ce45ebcccde15fc675a476460bc

if ! git show HEAD:README.md | grep -q 'Engineering Milestone 1.6'; then
  echo "ERROR: committed README is not Milestone 1.6. Commit the accepted 1.6 tree first."
  exit 1
fi

shasum -a 256 -c FILES.sha256

echo "[1/7] Strict C syntax"
clang -std=c11 -Wall -Wextra -Werror -fsyntax-only \
  -IZoneCore/include -IZoneCore/src -IZoneCore/Recovered/include \
  ZoneCore/src/zone_core.c
clang -std=c11 -Wall -Wextra -Werror -fsyntax-only \
  -IZoneCore/include -IZoneCore/src -IZoneCore/Recovered/include \
  ZoneCore/tests/test_zone_core.c

echo "[2/7] Recovered lifecycle promotion"
! grep -q 'ZONE_RESPAWN_TICKS' ZoneCore/src/zone_core.c
! grep -q 'ZONE_WAVE_CLEAR_TICKS' ZoneCore/src/zone_core.c
grep -q 'previous_type.*EXPL' ZoneCore/src/zone_core.c
grep -q 'update_explosions_and_lifecycle' ZoneCore/src/zone_core.c
grep -q 'respawn_pending' ZoneCore/src/zone_core.c
grep -q 'test_player_death_respawn_on_ship_explosion_completion' ZoneCore/tests/test_zone_core.c
grep -q 'test_recovered_explosion_cadence' ZoneCore/tests/test_zone_core.c

echo "[3/7] Projectile retirement remains explicitly unresolved"
grep -q 'TEMP: spatial/list retirement lift still pending' ZoneCore/src/zone_core.c
grep -q 'SHOT countdown; spatial retirement pending' ZoneCore/src/zone_core.c
grep -q 'Projectile lifetime finding' Docs/MILESTONE-1.7.md
grep -q 'SHOT/FIRE retirement' Docs/RE-timing-lifecycle.md

echo "[4/7] Accepted high-refresh host/render/audio untouched"
for path in Shared/ZoneGameHost.swift Shared/ZoneRenderer.swift Shared/ZoneAudioEngine.swift; do
  if ! git diff --quiet HEAD -- "$path"; then
    echo "ERROR: Milestone 1.7 must not modify $path"
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

echo "Milestone 1.7 verification: PASS"
