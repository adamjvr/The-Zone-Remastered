#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")/.."

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 0 verification"
echo "============================================================"

echo "[1/5] Instrumentation-only static scope"
grep -q 'Bee Parity Pass 0 known-good instrumentation' ZoneCore/src/zone_core.c
grep -q 'ZONE_BEE_TRACE' ZoneCore/src/zone_core.c
grep -q '\[BEE_TRACE\]' ZoneCore/src/zone_core.c
echo "PASS: instrumentation marker"

echo "[2/5] Patcher self-test"
python3 Tools/apply-bee-parity-pass0.py --self-test

echo "[3/5] Existing deterministic ZoneCore regression with trace OFF"
env -u ZONE_BEE_TRACE ./Tools/test-zonecore.sh

echo "[4/5] Trace path smoke test"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
ZONE_BEE_TRACE=1 ./Tools/test-zonecore.sh >"$TMP" 2>&1
grep -q '\[BEE_TRACE\]' "$TMP"
echo "PASS: trace emits when explicitly enabled"

echo "[5/5] Native target separation"
./Tools/verify-native-targets.command

echo
echo "Bee Parity Pass 0 verification: PASS"
