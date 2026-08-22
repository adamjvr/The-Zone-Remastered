#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
clang -std=c11 -Wall -Wextra -Werror \
  -IZoneCore/include -IZoneCore/src -IZoneCore/Recovered/include \
  ZoneCore/src/zone_core.c ZoneCore/src/zone_sprite_data.c \
  ZoneCore/Recovered/src/render.c \
  ZoneCore/Recovered/src/collision.c \
  ZoneCore/Recovered/src/player.c \
  ZoneCore/Recovered/src/waves.c \
  ZoneCore/Recovered/src/damage.c \
  ZoneCore/Recovered/src/objects.c \
  ZoneCore/tests/test_zone_core.c -lm -o build/zonecore-test
./build/zonecore-test
