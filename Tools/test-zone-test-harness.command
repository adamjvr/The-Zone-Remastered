#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")/.."
mkdir -p build

clang -std=c11 -Wall -Wextra -Werror \
  -IZoneCore/include -IZoneCore/src -IZoneCore/Recovered/include \
  ZoneCore/src/zone_core.c ZoneCore/src/zone_sprite_data.c \
  ZoneCore/Recovered/src/render.c \
  ZoneCore/Recovered/src/collision.c \
  ZoneCore/Recovered/src/ai.c \
  ZoneCore/Recovered/src/player.c \
  ZoneCore/Recovered/src/waves.c \
  ZoneCore/Recovered/src/damage.c \
  ZoneCore/Recovered/src/objects.c \
  ZoneCore/tests/test_zone_jump_harness.c -lm -o build/zone-jump-harness-test

env -u ZONE_TEST_MODE -u ZONE_TEST_START_ZONE \
  ./build/zone-jump-harness-test 1

env -u ZONE_TEST_MODE ZONE_TEST_START_ZONE=7 \
  ./build/zone-jump-harness-test 1

ZONE_TEST_MODE=1 ZONE_TEST_START_ZONE=2 \
  ./build/zone-jump-harness-test 2
ZONE_TEST_MODE=1 ZONE_TEST_START_ZONE=7 \
  ./build/zone-jump-harness-test 7
ZONE_TEST_MODE=1 ZONE_TEST_START_ZONE=18 \
  ./build/zone-jump-harness-test 18

ZONE_TEST_MODE=1 ZONE_TEST_START_ZONE=0 \
  ./build/zone-jump-harness-test 1
ZONE_TEST_MODE=1 ZONE_TEST_START_ZONE=19 \
  ./build/zone-jump-harness-test 1
ZONE_TEST_MODE=1 ZONE_TEST_START_ZONE=garbage \
  ./build/zone-jump-harness-test 1

echo "Zone Test Harness runtime regression: PASS"
