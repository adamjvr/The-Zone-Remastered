#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
BASE="92f4e1912310162992f067c70edb7133412b48ec"
EXPECTED_AUDIO_SHA="573f1fbdb25109a6c59a73682d38fb1dc1b02fb594d09a21f8b07604a25bda00"

if [[ "$(git rev-parse HEAD)" != "$BASE" ]]; then
  echo "ERROR: Milestone 1.4 verifier expects uncommitted overlay on base $BASE"
  echo "Actual HEAD: $(git rev-parse HEAD)"
  exit 1
fi

# ZoneCore may differ from 1.3 ONLY by the audited Raider omission repaired in
# 1.4.1. Construct that exact expected recovered AI file and compare it.
unexpected="$(git diff --name-only "$BASE" -- ZoneCore | grep -v '^ZoneCore/Recovered/src/ai.c$' || true)"
if [[ -n "$unexpected" ]]; then
  echo "ERROR: unexpected ZoneCore changes in Milestone 1.4:"
  echo "$unexpected"
  exit 1
fi
TMP_EXPECTED="$(mktemp)"
trap 'rm -f "$TMP_EXPECTED"' EXIT
git show "$BASE:ZoneCore/Recovered/src/ai.c" > "$TMP_EXPECTED"
python3 - "$TMP_EXPECTED" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
old = '''int16_t tz_enemy_fire_active_cap(uint32_t type) {
    switch (type) {
        case TZ_TYPE_BLOO:
        case TZ_TYPE_BEE:
        case TZ_TYPE_SEEK:
        case TZ_TYPE_ROTO:
            return 3;
        default:
            return 0;
    }
}
'''
new = '''int16_t tz_enemy_fire_active_cap(uint32_t type) {
    switch (type) {
        case TZ_TYPE_BLOO:
        case TZ_TYPE_BEE:
        case TZ_TYPE_RAID:
        case TZ_TYPE_SEEK:
        case TZ_TYPE_ROTO:
            return 3;
        default:
            return 0;
    }
}
'''
if old not in s:
    raise SystemExit('ERROR: committed base no longer matches expected Raider omission')
p.write_text(s.replace(old, new, 1))
PY
cmp -s "$TMP_EXPECTED" ZoneCore/Recovered/src/ai.c || {
  echo "ERROR: ZoneCore AI contains changes beyond the Raider cap correction"
  diff -u "$TMP_EXPECTED" ZoneCore/Recovered/src/ai.c || true
  exit 1
}

actual_audio_sha="$(shasum -a 256 Shared/ZoneAudioEngine.swift | awk '{print $1}')"
if [[ "$actual_audio_sha" != "$EXPECTED_AUDIO_SHA" ]]; then
  echo "ERROR: ZoneAudioEngine.swift is not the audited 1.4.2 render-graph backend"
  echo "Expected: $EXPECTED_AUDIO_SHA"
  echo "Actual:   $actual_audio_sha"
  exit 1
fi

grep -q 'AVAudioEngine()' Shared/ZoneAudioEngine.swift
grep -q 'AVAudioPlayerNode()' Shared/ZoneAudioEngine.swift
grep -q 'scheduleBuffer(bank.buffer' Shared/ZoneAudioEngine.swift
! grep -q 'AVAudioPlayer(data:' Shared/ZoneAudioEngine.swift
! grep -q 'currentTime = 0' Shared/ZoneAudioEngine.swift

grep -q 'static let masterHz: UInt64 = 720' Shared/ZoneGameHost.swift
grep -q 'static let masterTicksPerClassicStep: UInt64 = masterHz / classicHz' Shared/ZoneGameHost.swift
grep -q 'host.advance(presentationTime: frameStart)' Shared/ZoneRenderer.swift
! grep -q 'host.step()' Shared/ZoneRenderer.swift
grep -q 'maximumFramesPerSecond' Shared/ZoneMetalView.swift
grep -q 'ZONE_PRESENTATION_HZ' Shared/ZoneMetalView.swift
grep -q 'Current phase: Milestone 1.4' Docs/ROADMAP.md
grep -q 'Engineering Milestone 1.4' README.md

xcrun swiftc -parse Shared/ZoneAudioEngine.swift
xcrun swiftc -parse Shared/ZoneGameHost.swift
xcrun swiftc -parse Shared/ZoneRenderer.swift
xcrun swiftc -parse Shared/ZoneMetalView.swift

./Tools/test-zone-timebase.command
./Tools/test-zonecore.sh
./Tools/benchmark-zonecore.command 240
./Tools/verify-native-targets.command

echo
echo "Milestone 1.4 verification passed."
echo "720-Hz timebase remains intact."
echo "Raider 3-shot cap correction remains exact."
echo "Native audio backend is AVAudioEngine + predecoded PCM + persistent player nodes."
