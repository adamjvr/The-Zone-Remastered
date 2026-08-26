#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

EXPECTED_BASE="d0aea36c484ceffd796717ded325d660f8243ed5"
if ! command -v git >/dev/null 2>&1; then
  echo "ERROR: git is required." >&2
  exit 1
fi
if [ ! -d .git ]; then
  echo "ERROR: run this from the root of The-Zone-Remastered (the ZIP is designed to be extracted there)." >&2
  exit 1
fi

HEAD="$(git rev-parse HEAD)"
if [ "$HEAD" != "$EXPECTED_BASE" ]; then
  echo "ERROR: Milestone 1.11 was built against $EXPECTED_BASE (Milestone 1.10)." >&2
  echo "Current HEAD: $HEAD" >&2
  echo "Refusing to guess across a different source tree." >&2
  exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  echo "ERROR: tracked files have local modifications. Commit/stash them first." >&2
  git status --short >&2
  exit 1
fi

python3 Tools/apply-milestone-1.11.py
chmod +x Tools/verify-milestone-1.11.command Tools/test-spatial-1.11.sh
./Tools/verify-milestone-1.11.command

echo
echo "Milestone 1.11 applied and verified."
echo "Next: ./Tools/build-macos.command"
echo "Run:  ./Tools/run-macos-refresh.command native high"
echo "Direct gameplay: ZONE_BOOT_DIRECT=1 ./Tools/run-macos-refresh.command native high"
