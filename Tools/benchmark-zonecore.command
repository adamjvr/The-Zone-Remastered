#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
mkdir -p build
OUT="build/zonecore-benchmark"
clang -std=c11 -O2 -DNDEBUG -Wall -Wextra -Werror \
  -IZoneCore/include -IZoneCore/src -IZoneCore/Recovered/include \
  ZoneCore/src/zone_core.c ZoneCore/src/zone_sprite_data.c \
  ZoneCore/Recovered/src/render.c \
  ZoneCore/Recovered/src/collision.c \
  ZoneCore/Recovered/src/ai.c \
  ZoneCore/Recovered/src/player.c \
  ZoneCore/Recovered/src/waves.c \
  ZoneCore/Recovered/src/damage.c \
  ZoneCore/Recovered/src/objects.c \
  Tools/zonecore-benchmark.c -lm -o "$OUT"
"$OUT" "${1:-12000}"
