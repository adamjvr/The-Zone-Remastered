#!/bin/zsh
set -euo pipefail
BASE="92f4e1912310162992f067c70edb7133412b48ec"

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi
if [[ "$(git rev-parse HEAD)" != "$BASE" ]]; then
  echo "ERROR: 1.4.2 expects the uncommitted 1.4/1.4.1 working tree on committed 1.3."
  echo "Expected HEAD: $BASE"
  echo "Actual HEAD:   $(git rev-parse HEAD)"
  exit 1
fi

grep -q 'static let masterHz: UInt64 = 720' Shared/ZoneGameHost.swift || {
  echo "ERROR: Milestone 1.4 timebase overlay is not present."
  exit 1
}
grep -q 'case TZ_TYPE_RAID:' ZoneCore/Recovered/src/ai.c || {
  echo "ERROR: Milestone 1.4.1 Raider fire-cap hotfix is not present."
  exit 1
}

if [[ ! -f FILES.sha256 ]]; then
  echo "ERROR: FILES.sha256 missing; re-extract the 1.4.2 ZIP into the repo root."
  exit 1
fi
shasum -a 256 -c FILES.sha256

chmod +x Tools/verify-milestone-1.4.command Tools/test-zonecore.sh Tools/test-zone-timebase.command Tools/benchmark-zonecore.command Tools/verify-native-targets.command 2>/dev/null || true
./Tools/verify-milestone-1.4.command

echo
echo "Milestone 1.4.2 AVAudioEngine hotfix applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "A/B:   ./Tools/run-macos-refresh.command 60"
echo "Native: ./Tools/run-macos-refresh.command native"
echo "Do not commit until the audio-stall play test is accepted."
