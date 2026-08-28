#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")/.."

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 3A verification"
echo "============================================================"

echo "[1/6] Accepted Bee semantics retained"
grep -q 'Bee Parity Pass 1 requester quota is cumulative for the wave' ZoneCore/src/zone_core.c
grep -q 'Bee Parity Pass 2 donor +74 releases at Bee EXPL finalization' ZoneCore/src/zone_core.c
echo "PASS: Pass 1 + Pass 2 retained"

echo "[2/6] Firing instrumentation markers"
grep -q 'Bee Parity Pass 3A firing forensics only' ZoneCore/src/zone_core.c
grep -q 'ZONE_BEE_FIRE_TRACE' ZoneCore/src/zone_core.c
grep -q '\[BEE_FIRE_TRACE\]' ZoneCore/src/zone_core.c
echo "PASS: Pass 3A markers"

echo "[3/6] No world-spatial transplant"
if grep -q 'ZONE_WORLD_EXTENT' ZoneCore/src/zone_core.c; then
  echo "ERROR: unexpected 1056-world spatial code appeared in Pass 3A" >&2
  exit 1
fi
echo "PASS: known-good 640x480 world model intentionally unchanged"

echo "[4/6] Patcher self-test"
python3 Tools/apply-bee-parity-pass3a.py --self-test

echo "[5/6] Full deterministic regression, trace OFF"
env -u ZONE_BEE_FIRE_TRACE ./Tools/test-zonecore.sh

echo "[6/6] Trace-on regression smoke test"
TMP="$(mktemp)"; trap 'rm -f "$TMP"' EXIT
ZONE_BEE_FIRE_TRACE=1 ./Tools/test-zonecore.sh >"$TMP" 2>&1
grep -q '\[BEE_FIRE_TRACE\]' "$TMP"
echo "PASS: firing trace emits with tests still passing"

echo
echo "Bee Parity Pass 3A verification: PASS"
