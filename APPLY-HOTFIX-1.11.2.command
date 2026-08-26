#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
cd "$(dirname "$0")"

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi

expected_head="d0aea36c484ceffd796717ded325d660f8243ed5"
actual_head="$(/usr/bin/git rev-parse HEAD)"
if [[ "$actual_head" != "$expected_head" ]]; then
  echo "ERROR: Hotfix 1.11.2 expects the uncommitted 1.11/1.11.1 candidate on accepted 1.10."
  echo "Expected committed HEAD: $expected_head"
  echo "Actual HEAD:             $actual_head"
  exit 1
fi

if [[ ! -f Docs/MILESTONE-1.11.md ]] || ! /usr/bin/grep -q 'Milestone 1.11' Docs/MILESTONE-1.11.md; then
  echo "ERROR: Milestone 1.11 candidate is not present."
  exit 1
fi

if ! /usr/bin/grep -q 'Milestone 1.11.1 front-end frame-pacing hotfix' Shared/ZoneContentView.swift; then
  echo "ERROR: Hotfix 1.11.1 is not present. Apply 1.11.1 before 1.11.2."
  exit 1
fi

/usr/bin/shasum -a 256 -c FILES-HOTFIX-1.11.2.sha256
/usr/bin/python3 Tools/apply-hotfix-1.11.2.py
/bin/chmod +x APPLY-HOTFIX-1.11.2.command Tools/verify-hotfix-1.11.2.command Tools/apply-hotfix-1.11.2.py
./Tools/verify-hotfix-1.11.2.command

echo
echo "Hotfix 1.11.2 applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Run:   ./Tools/run-macos-refresh.command native high"
echo "Watch at least one full ~9.6-second title-ship revolution."
