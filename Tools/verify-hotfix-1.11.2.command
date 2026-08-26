#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
SOURCE="Shared/ZoneContentView.swift"

echo "[1/6] 1.11 + 1.11.1 prerequisites"
/usr/bin/grep -q 'Milestone 1.11.1 front-end frame-pacing hotfix' "$SOURCE"
/usr/bin/grep -q 'profile.valueDidChangeHandler' "$SOURCE"
if /usr/bin/grep -q 'Timer(timeInterval: 1.0 / 60.0' "$SOURCE"; then
  echo "ERROR: legacy menu polling timer returned"
  exit 1
fi

echo "[2/6] 1.11.2 predecoded frame store"
/usr/bin/grep -q 'Milestone 1.11.2 predecoded interpolated title ship' "$SOURCE"
/usr/bin/grep -q 'import ImageIO' "$SOURCE"
/usr/bin/grep -q 'kCGImageSourceShouldCacheImmediately' "$SOURCE"
/usr/bin/grep -q 'private enum ZoneTitleShipFrameStore' "$SOURCE"
if /usr/bin/grep -q 'private enum ZoneBundledSpriteCache' "$SOURCE"; then
  echo "ERROR: 1.11.1 lazy cache is still present"
  exit 1
fi

echo "[3/6] Continuous recovered-pose interpolation"
/usr/bin/grep -q 'frameStepDegrees = 360.0 / 48.0' "$SOURCE"
/usr/bin/grep -q 'interpolatedStepDegrees = spriteBlend \* frameStepDegrees' "$SOURCE"
/usr/bin/grep -q 'rotationEffect(.degrees(interpolatedStepDegrees))' "$SOURCE"
/usr/bin/grep -q 'rotationEffect(.degrees(interpolatedStepDegrees - frameStepDegrees))' "$SOURCE"

echo "[4/6] Display-driven title clocks preserved"
count="$(/usr/bin/grep -c 'TimelineView(.animation(paused: reduceMotion))' "$SOURCE" || true)"
if [[ "$count" -lt 2 ]]; then
  echo "ERROR: expected display-driven animation schedules for ship + starfield"
  exit 1
fi
if /usr/bin/grep -q 'minimumInterval: 1.0 / 24.0' "$SOURCE"; then
  echo "ERROR: legacy 24-Hz title clock returned"
  exit 1
fi

echo "[5/6] Patcher self-test"
/usr/bin/python3 Tools/apply-hotfix-1.11.2.py --self-test

echo "[6/6] Milestone 1.11 gameplay/spatial regression"
./Tools/verify-milestone-1.11.command

echo "Hotfix 1.11.2 title animation verification: PASS"
