#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")"

echo "============================================================"
echo "The Zone Remastered — Zone Test Harness 0.1"
echo "Direct fixed-Zone startup for forensic testing"
echo "============================================================"

if [[ ! -d .git || ! -f ZoneCore/src/zone_core.c ]]; then
  echo "ERROR: extract this ZIP into the The-Zone-Remastered repository root." >&2
  exit 1
fi

grep -q 'Bee Parity Pass 2 donor +74 releases at Bee EXPL finalization' ZoneCore/src/zone_core.c || {
  echo "ERROR: expected accepted Bee Parity Pass 2 source state." >&2
  exit 1
}

shasum -a 256 -c FILES-ZONE-TEST-HARNESS-0.1.sha256
python3 Tools/apply-zone-test-harness-0.1.py

chmod +x APPLY-ZONE-TEST-HARNESS-0.1.command \
  Tools/apply-zone-test-harness-0.1.py \
  Tools/run-macos-zone-test.command \
  Tools/test-zone-test-harness.command \
  Tools/verify-zone-test-harness-0.1.command

./Tools/verify-zone-test-harness-0.1.command

echo
echo "Zone Test Harness 0.1 applied and verified."
echo
echo "Examples:"
echo "  ./Tools/run-macos-zone-test.command 2"
echo "  ./Tools/run-macos-zone-test.command 7"
echo "  ./Tools/run-macos-zone-test.command 18 native high"
echo
echo "Trace switches are inherited, e.g.:"
echo "  ZONE_BEE_FIRE_TRACE=1 ./Tools/run-macos-zone-test.command 7"
