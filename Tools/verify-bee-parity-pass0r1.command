#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")/.."

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 0r1 verification"
echo "============================================================"

echo "[1/6] Pass-0 instrumentation retained"
grep -q 'Bee Parity Pass 0 known-good instrumentation' ZoneCore/src/zone_core.c
grep -q 'Bee Parity Pass 0r1 trace-string repair' ZoneCore/src/zone_core.c
echo "PASS: instrumentation retained"

echo "[2/6] Repaired C trace strings"
python3 - <<'PY'
from pathlib import Path
s = Path("ZoneCore/src/zone_core.c").read_text()
bad = [
    '"damage=%d request_count=%d limit=%d active_bees=%d\n",',
    '"active_bees_before_remove=%d\n",',
]
for item in bad:
    assert item not in s, repr(item)
assert '"damage=%d request_count=%d limit=%d active_bees=%d\\n",' in s
assert '"active_bees_before_remove=%d\\n",' in s
print("PASS: no literal newline remains inside the affected C strings")
PY

echo "[3/6] Repair-script self-test"
python3 Tools/repair-bee-parity-pass0r1.py --self-test

echo "[4/6] Existing deterministic ZoneCore regression with trace OFF"
env -u ZONE_BEE_TRACE ./Tools/test-zonecore.sh

echo "[5/6] Trace path smoke test"
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
ZONE_BEE_TRACE=1 ./Tools/test-zonecore.sh >"$TMP" 2>&1
grep -q '\[BEE_TRACE\]' "$TMP"
echo "PASS: trace emits when explicitly enabled"

echo "[6/6] Native target separation"
./Tools/verify-native-targets.command

echo
echo "Bee Parity Pass 0r1 verification: PASS"
