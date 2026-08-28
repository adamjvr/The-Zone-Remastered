#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")"

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 3A"
echo "Bee firing forensics ONLY"
echo "============================================================"

if [[ ! -d .git || ! -f ZoneCore/src/zone_core.c ]]; then
  echo "ERROR: extract this ZIP into the repository root." >&2
  exit 1
fi

grep -q 'Bee Parity Pass 1 requester quota is cumulative for the wave' ZoneCore/src/zone_core.c || {
  echo "ERROR: accepted Bee Parity Pass 1 source is not present." >&2
  exit 1
}
grep -q 'Bee Parity Pass 2 donor +74 releases at Bee EXPL finalization' ZoneCore/src/zone_core.c || {
  echo "ERROR: accepted Bee Parity Pass 2 source is not present." >&2
  exit 1
}

shasum -a 256 -c FILES-BEE-PARITY-PASS3A.sha256
python3 Tools/apply-bee-parity-pass3a.py
chmod +x APPLY-BEE-PARITY-PASS3A.command Tools/*.command Tools/*.py
./Tools/verify-bee-parity-pass3a.command

echo
echo "Bee Parity Pass 3A applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Trace: ./Tools/run-macos-bee-fire-trace.command"
