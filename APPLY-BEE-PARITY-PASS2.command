#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")"

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 2"
echo "Donor occupancy finalization timing ONLY"
echo "============================================================"

if [[ ! -d .git || ! -f ZoneCore/src/zone_core.c || ! -f ZoneCore/tests/test_zone_core.c ]]; then
  echo "ERROR: extract this ZIP into the The-Zone-Remastered repository root." >&2
  exit 1
fi

grep -q 'Bee Parity Pass 0 known-good instrumentation' ZoneCore/src/zone_core.c || {
  echo "ERROR: Bee Parity Pass 0 instrumentation is not present." >&2
  exit 1
}
grep -q 'Bee Parity Pass 0r1 trace-string repair' ZoneCore/src/zone_core.c || {
  echo "ERROR: Bee Parity Pass 0r1 repair is not present." >&2
  exit 1
}
grep -q 'Bee Parity Pass 1 requester quota is cumulative for the wave' ZoneCore/src/zone_core.c || {
  echo "ERROR: Bee Parity Pass 1 is not present." >&2
  exit 1
}

shasum -a 256 -c FILES-BEE-PARITY-PASS2.sha256
python3 Tools/apply-bee-parity-pass2.py
chmod +x APPLY-BEE-PARITY-PASS2.command Tools/apply-bee-parity-pass2.py Tools/verify-bee-parity-pass2.command
./Tools/verify-bee-parity-pass2.command

echo
echo "Bee Parity Pass 2 applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Trace: ./Tools/run-macos-bee-trace.command"
