#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE="Shared/ZoneContentView.swift"

echo "[1/4] Cinematic title-motion markers"
/usr/bin/grep -q 'Milestone 1.11.4 cinematic title motion' "$SOURCE"
/usr/bin/grep -q 'ZONE_TITLE_ROTATION_SECONDS' "$SOURCE"
/usr/bin/grep -q '?? 24.0' "$SOURCE"
/usr/bin/grep -q 'spriteFramesPerSecond = 48.0 / cycleDuration' "$SOURCE"

echo "[2/4] Slow independent ring drift"
/usr/bin/grep -q 'time \* 7.5' "$SOURCE"
/usr/bin/grep -q 'time \* -4.0' "$SOURCE"
if /usr/bin/grep -q 'time \* 37.5' "$SOURCE"; then
  echo "ERROR: legacy fast primary ring speed remains" >&2
  exit 1
fi
if /usr/bin/grep -q 'time \* -18.75' "$SOURCE"; then
  echo "ERROR: legacy fast secondary ring speed remains" >&2
  exit 1
fi

echo "[3/4] Patcher self-test"
/usr/bin/python3 Tools/apply-hotfix-1.11.4.py --self-test

echo "[4/4] Prior title/input/gameplay regressions"
./Tools/verify-hotfix-1.11.3.command

echo "Hotfix 1.11.4 cinematic title motion: PASS"
