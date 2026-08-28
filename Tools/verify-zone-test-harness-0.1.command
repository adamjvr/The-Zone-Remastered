#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")/.."

echo "============================================================"
echo "The Zone Remastered — Zone Test Harness 0.1 verification"
echo "============================================================"

echo "[1/6] Accepted Bee checkpoint retained"
grep -q 'Bee Parity Pass 2 donor +74 releases at Bee EXPL finalization' ZoneCore/src/zone_core.c
grep -q 'event=bee_donor_release' ZoneCore/src/zone_core.c
if grep -q -- '--requester->bee_request_count' ZoneCore/src/zone_core.c; then
  echo "ERROR: Pass 1 requester quota fix was lost." >&2
  exit 1
fi
echo "PASS: Bee Passes 1-2 retained"

echo "[2/6] Harness static markers"
grep -q 'Zone Test Harness 0.1 environment-gated fixed-Zone startup' ZoneCore/src/zone_core.c
grep -q 'ZONE_TEST_MODE' ZoneCore/src/zone_core.c
grep -q 'ZONE_TEST_START_ZONE' ZoneCore/src/zone_core.c
echo "PASS: test-mode startup hook"

echo "[3/6] Patcher self-test"
python3 Tools/apply-zone-test-harness-0.1.py --self-test

echo "[4/6] Full existing ZoneCore regression — test mode OFF"
env -u ZONE_TEST_MODE -u ZONE_TEST_START_ZONE ./Tools/test-zonecore.sh

echo "[5/6] Direct Zone-jump runtime regression"
./Tools/test-zone-test-harness.command

echo "[6/6] Native target separation"
./Tools/verify-native-targets.command

echo
echo "Zone Test Harness 0.1 verification: PASS"
