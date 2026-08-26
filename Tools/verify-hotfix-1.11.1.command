#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

SOURCE="Shared/ZoneContentView.swift"

echo "[1/5] Front-end pacing markers"
/usr/bin/grep -q 'Milestone 1.11.1 front-end frame-pacing hotfix' "$SOURCE"
/usr/bin/grep -q 'profile.valueDidChangeHandler' "$SOURCE"
if /usr/bin/grep -q 'Timer(timeInterval: 1.0 / 60.0' "$SOURCE"; then
  echo "ERROR: legacy 60-Hz menu polling Timer is still present"
  exit 1
fi

echo "[2/5] Display-driven title timelines"
count="$(/usr/bin/grep -c 'TimelineView(.animation(paused: reduceMotion))' "$SOURCE" || true)"
if [[ "$count" -lt 2 ]]; then
  echo "ERROR: expected display-driven animation schedules for ship + starfield"
  exit 1
fi
if /usr/bin/grep -q 'minimumInterval: 1.0 / 24.0' "$SOURCE"; then
  echo "ERROR: legacy 24-Hz ship timeline is still present"
  exit 1
fi

echo "[3/5] Smooth title ship + cached sprite I/O"
/usr/bin/grep -q 'spriteBlend' "$SOURCE"
/usr/bin/grep -q 'primaryRingDegrees' "$SOURCE"
/usr/bin/grep -q 'private enum ZoneBundledSpriteCache' "$SOURCE"
/usr/bin/grep -q 'images.object(forKey: key)' "$SOURCE"

echo "[4/5] Patcher self-test"
/usr/bin/python3 Tools/apply-hotfix-1.11.1.py --self-test

echo "[5/5] Milestone 1.11 gameplay/spatial regression"
./Tools/verify-milestone-1.11.command

echo "Milestone 1.11.1 title frame-pacing verification: PASS"
