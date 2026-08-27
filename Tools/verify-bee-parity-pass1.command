#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")/.."

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 1 verification"
echo "============================================================"

echo "[1/6] Pass-0 diagnostic control retained"
grep -q 'Bee Parity Pass 0 known-good instrumentation' ZoneCore/src/zone_core.c
grep -q 'Bee Parity Pass 0r1 trace-string repair' ZoneCore/src/zone_core.c
echo "PASS: diagnostic control retained"

echo "[2/6] Requester quota semantics"
grep -q 'Bee Parity Pass 1 requester quota is cumulative for the wave' ZoneCore/src/zone_core.c
if grep -q -- '--requester->bee_request_count' ZoneCore/src/zone_core.c; then
  echo "ERROR: requester quota refund still present." >&2
  exit 1
fi
echo "PASS: requester quota is not refunded"

echo "[3/6] Donor lifecycle deliberately unchanged"
python3 - <<'PYCHECK'
from pathlib import Path
s = Path('ZoneCore/src/zone_core.c').read_text()
needle = '''if (destroyed_type == TZ_TYPE_BEE) {
                    if (parent->bee_out_count > 0) --parent->bee_out_count;
                }'''
assert needle in s, 'Pass 1 accidentally changed donor cleanup'
print('PASS: donor +74 release remains pre-Pass-1 behavior')
PYCHECK

echo "[4/6] Patcher self-test"
python3 Tools/apply-bee-parity-pass1.py --self-test

echo "[5/6] Full deterministic ZoneCore regression"
env -u ZONE_BEE_TRACE ./Tools/test-zonecore.sh

echo "[6/6] Native target separation"
./Tools/verify-native-targets.command

echo
echo "Bee Parity Pass 1 verification: PASS"
