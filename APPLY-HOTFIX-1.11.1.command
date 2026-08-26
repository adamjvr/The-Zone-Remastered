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
  echo "ERROR: Hotfix 1.11.1 expects the uncommitted 1.11 candidate on top of accepted 1.10."
  echo "Expected committed HEAD: $expected_head"
  echo "Actual HEAD:             $actual_head"
  exit 1
fi

if [[ ! -f Docs/MILESTONE-1.11.md ]] || ! /usr/bin/grep -q 'Milestone 1.11' Docs/MILESTONE-1.11.md; then
  echo "ERROR: Milestone 1.11 candidate is not present. Apply 1.11 first."
  exit 1
fi

# Verify only this hotfix payload. FILES-HOTFIX-1.11.1.sha256 intentionally
# excludes the target source because the Python patcher edits it in place.
/usr/bin/shasum -a 256 -c FILES-HOTFIX-1.11.1.sha256

/usr/bin/python3 Tools/apply-hotfix-1.11.1.py
/bin/chmod +x APPLY-HOTFIX-1.11.1.command Tools/verify-hotfix-1.11.1.command Tools/apply-hotfix-1.11.1.py
./Tools/verify-hotfix-1.11.1.command

echo
echo "Hotfix 1.11.1 applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Run:   ./Tools/run-macos-refresh.command native high"
echo "Then compare idle title animation, keyboard navigation, and controller navigation."
