#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")/.."

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 2 verification"
echo "============================================================"

echo "[1/7] Previous accepted Bee passes retained"
grep -q 'Bee Parity Pass 0 known-good instrumentation' ZoneCore/src/zone_core.c
grep -q 'Bee Parity Pass 0r1 trace-string repair' ZoneCore/src/zone_core.c
grep -q 'Bee Parity Pass 1 requester quota is cumulative for the wave' ZoneCore/src/zone_core.c
if grep -q -- '--requester->bee_request_count' ZoneCore/src/zone_core.c; then
  echo "ERROR: Pass 1 requester quota refund returned." >&2
  exit 1
fi
echo "PASS: Pass 0/1 behavior retained"

echo "[2/7] Bee donor retained through EXPL"
grep -q 'Bee Parity Pass 2 donor +74 releases at Bee EXPL finalization' ZoneCore/src/zone_core.c
grep -q 'Bee +142 donor retained through EXPL finalization' ZoneCore/src/zone_core.c
grep -q 'event=bee_donor_release' ZoneCore/src/zone_core.c
echo "PASS: delayed donor release source present"

echo "[3/7] Debug counter accessors"
grep -q 'zone_game_debug_world_bee_out_count' ZoneCore/include/zone_core.h
grep -q 'zone_game_debug_world_bee_request_count' ZoneCore/include/zone_core.h
echo "PASS: +74/+76 debug visibility"

echo "[4/7] Patcher self-test"
python3 Tools/apply-bee-parity-pass2.py --self-test

echo "[5/7] Full deterministic ZoneCore regression"
env -u ZONE_BEE_TRACE ./Tools/test-zonecore.sh

echo "[6/7] Bee donor-release trace smoke test"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
ZONE_BEE_TRACE=1 ./Tools/test-zonecore.sh >"$TMP" 2>&1
grep -q 'event=bee_donor_release' "$TMP"
echo "PASS: donor release occurs on Bee EXPL finalization"

echo "[7/7] Native target separation"
./Tools/verify-native-targets.command

echo
echo "Bee Parity Pass 2 verification: PASS"
