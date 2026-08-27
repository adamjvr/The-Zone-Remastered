#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")"

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 0r1"
echo "Trace-string compile repair ONLY"
echo "============================================================"

if [[ ! -d .git || ! -f ZoneCore/src/zone_core.c ]]; then
  echo "ERROR: extract this ZIP into the The-Zone-Remastered repository root." >&2
  exit 1
fi

if ! grep -q 'Bee Parity Pass 0 known-good instrumentation' ZoneCore/src/zone_core.c; then
  echo "ERROR: Bee Parity Pass 0 instrumentation is not present." >&2
  exit 1
fi

shasum -a 256 -c FILES-BEE-PARITY-PASS0R1.sha256

python3 Tools/repair-bee-parity-pass0r1.py

# Remove accidental Python bytecode that slipped into the original Pass-0 ZIP.
rm -rf Tools/__pycache__

chmod +x APPLY-BEE-PARITY-PASS0R1.command \
  Tools/repair-bee-parity-pass0r1.py \
  Tools/verify-bee-parity-pass0r1.command

./Tools/verify-bee-parity-pass0r1.command

echo
echo "Bee Parity Pass 0r1 applied and verified."
echo
echo "Build:"
echo "  ./Tools/build-macos.command"
echo
echo "Trace session:"
echo "  ./Tools/run-macos-bee-trace.command"
