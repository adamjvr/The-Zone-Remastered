#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/5] Static recovered constants"
grep -q '#define ZONE_WORLD_EXTENT 1056' ZoneCore/include/zone_core.h
grep -q '#define ZONE_RADAR_WIDTH 110' ZoneCore/include/zone_core.h

echo "[2/5] Source integration markers"
grep -q 'Milestone 1.11 recovered world/camera/radar spatial lifecycle' ZoneCore/src/zone_core.c
grep -q 'radar_registered' ZoneCore/src/zone_core.c
grep -q 'camera_follow_player' ZoneCore/src/zone_core.c

echo "[3/5] Dedicated spatial regression"
./Tools/test-spatial-1.11.sh

echo "[4/5] Full ZoneCore regression"
./Tools/test-zonecore.sh

echo "[5/5] Native target configuration"
./Tools/verify-native-targets.command

echo "Milestone 1.11 verification: PASS"
