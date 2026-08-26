#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

echo "============================================================"
echo "The Zone Remastered — Hotfix 1.11.4"
echo "Cinematic title motion"
echo "============================================================"

if [[ ! -f Shared/ZoneContentView.swift ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root" >&2
  exit 1
fi

/usr/bin/python3 Tools/apply-hotfix-1.11.4.py
./Tools/verify-hotfix-1.11.4.command

echo
echo "Hotfix 1.11.4 applied and verified."
echo "Default title ship rotation: 24 seconds/revolution"
echo "Optional tuning: ZONE_TITLE_ROTATION_SECONDS=30 ./Tools/run-macos-refresh.command native high"
echo "Do not commit until the visual test is accepted."
