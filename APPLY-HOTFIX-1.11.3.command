#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
cd "$(dirname "$0")"

if [[ ! -d .git ]]; then
  echo "ERROR: extract this ZIP into the The-Zone-Remastered repository root."
  exit 1
fi

if ! grep -q 'Milestone 1.11.2 predecoded interpolated title ship' Shared/ZoneContentView.swift; then
  echo "ERROR: Hotfix 1.11.2 must be applied before 1.11.3."
  exit 1
fi

/usr/bin/python3 Tools/apply-hotfix-1.11.3.py
chmod +x Tools/verify-hotfix-1.11.3.command
./Tools/verify-hotfix-1.11.3.command

echo
echo "Hotfix 1.11.3r1 applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Run:   ./Tools/run-macos-refresh.command native high"
echo "Test title both inactive (Terminal frontmost) and active (The Zone frontmost)."
