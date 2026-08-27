#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:${PATH:-}"
cd "$(dirname "$0")"

EXPECTED_HEAD="4d5568949bd6d2844547789dc85c6d9ec332c9c2"

echo "============================================================"
echo "The Zone Remastered — Bee Parity Pass 0"
echo "Known-good baseline instrumentation ONLY"
echo "============================================================"

if [[ ! -d .git || ! -f ZoneCore/src/zone_core.c ]]; then
  echo "ERROR: extract this ZIP into the The-Zone-Remastered repository root." >&2
  exit 1
fi

HEAD_NOW="$(git rev-parse HEAD)"
if [[ "$HEAD_NOW" != "$EXPECTED_HEAD" ]]; then
  echo "ERROR: Pass 0 must begin from the known-good 1.11.4 baseline." >&2
  echo "Expected: $EXPECTED_HEAD" >&2
  echo "Actual:   $HEAD_NOW" >&2
  exit 1
fi

if ! git diff --quiet -- ZoneCore/src/zone_core.c; then
  echo "ERROR: ZoneCore/src/zone_core.c already has tracked edits." >&2
  git diff -- ZoneCore/src/zone_core.c >&2
  exit 1
fi

shasum -a 256 -c FILES-BEE-PARITY-PASS0.sha256
python3 Tools/apply-bee-parity-pass0.py

chmod +x APPLY-BEE-PARITY-PASS0.command \
  Tools/apply-bee-parity-pass0.py \
  Tools/verify-bee-parity-pass0.command \
  Tools/run-macos-bee-trace.command \
  Tools/summarize-bee-trace.py

./Tools/verify-bee-parity-pass0.command

echo
echo "Bee Parity Pass 0 applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Trace: ./Tools/run-macos-bee-trace.command"
