#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."

./Tools/test-zonecore.sh

[[ -f Docs/ReverseEngineering/Resources/Math_00002_MuzzleOffsets.bin ]] || {
  print -u2 "ERROR: missing original Math #2 muzzle-offset resource"
  exit 1
}
[[ $(stat -f %z Docs/ReverseEngineering/Resources/Math_00002_MuzzleOffsets.bin 2>/dev/null || stat -c %s Docs/ReverseEngineering/Resources/Math_00002_MuzzleOffsets.bin) -eq 192 ]] || {
  print -u2 "ERROR: Math #2 resource is not 192 bytes"
  exit 1
}

grep -q 'Text("BASES' Shared/ZoneContentView.swift
grep -q 'Math resource #2' ZoneCore/Recovered/src/player.c

print "Milestone 0.3 verification: PASS"
