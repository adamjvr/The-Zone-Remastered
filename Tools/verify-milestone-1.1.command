#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
BASE="6df5e5da9985eaa379a385c5e49af49c8f9e912c"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

[[ "$(git rev-parse HEAD)" == "$BASE" ]] || fail "HEAD must remain committed Milestone 1.0 ($BASE) while validating this uncommitted candidate"

# Hard guardrail: rejected timing experiment must not survive.
git diff --quiet "$BASE" -- ZoneCore || fail "ZoneCore differs from Milestone 1.0; this milestone must not change simulation/gameplay code"
git diff --quiet "$BASE" -- Shared/ZoneGameHost.swift || fail "ZoneGameHost differs from Milestone 1.0; 60-Hz host stepping must remain untouched"
pass "ZoneCore and ZoneGameHost remain byte-for-byte at Milestone 1.0"

# Renderer contract.
grep -q 'view.preferredFramesPerSecond = 60' Shared/ZoneRenderer.swift || fail "60-Hz presentation request missing"
grep -q 'host.step()' Shared/ZoneRenderer.swift || fail "Milestone 1.0 host.step() path missing"
grep -q 'preloadSpriteTextures()' Shared/ZoneRenderer.swift || fail "sprite texture preloader missing"
grep -q 'withUnsafeTemporaryAllocation(of: Vertex.self, capacity: 6)' Shared/ZoneRenderer.swift || fail "per-quad stack vertex storage missing"
grep -q 'frame-gap' Shared/ZoneRenderer.swift || fail "frame-gap diagnostics missing"
if grep -Eq 'ZoneFixedStepClock|presentationAlpha|wrappedLerp|extrapolat|interpolat' Shared/ZoneRenderer.swift Shared/ZoneGameHost.swift; then
  fail "rejected interpolation/fixed-step experiment marker is present"
fi
python3 - <<'PY'
from pathlib import Path
s=Path('Shared/ZoneRenderer.swift').read_text()
a=s.index('  private func texture(_ id: Int32) -> MTLTexture {')
b=s.index('  private func drawQuad(', a)
hot=s[a:b]
for forbidden in ('newTexture', 'Bundle.main.url', 'Data(contentsOf'):
    if forbidden in hot:
        raise SystemExit(f'FAIL: renderer hot texture lookup contains {forbidden}')
print('PASS: texture(_:) is cache-only during gameplay')
PY

# Audio contract.
grep -q 'voicesPerSound = 16' Shared/ZoneAudioEngine.swift || fail "16-voice prepared bank missing"
grep -q 'preloadMappedSounds()' Shared/ZoneAudioEngine.swift || fail "audio preloader missing"
grep -q 'AVAudioPlayer(data: data)' Shared/ZoneAudioEngine.swift || fail "prepared data-backed voices missing"
python3 - <<'PY'
from pathlib import Path
s=Path('Shared/ZoneAudioEngine.swift').read_text()
a=s.index('  func play(_ event: ZoneAudioEvent) {')
hot=s[a:]
for forbidden in ('Data(contentsOf:', 'AVAudioPlayer(contentsOf:', 'prepareToPlay()'):
    if forbidden in hot:
        raise SystemExit(f'FAIL: audio play hot path contains {forbidden}')
print('PASS: audio play(_:) performs no file/player construction')
PY

./Tools/test-zonecore.sh
pass "full ZoneCore regression suite"

swiftc -parse Shared/ZoneRenderer.swift Shared/ZoneAudioEngine.swift Shared/ZoneGameHost.swift
pass "Swift parse"

if [[ -x Tools/verify-native-targets.command ]]; then
  ./Tools/verify-native-targets.command
  pass "native target verification"
fi

grep -q 'Milestone 1.1 — Real-Time Hot-Path Repair' Docs/MILESTONE-1.1.md || fail "milestone documentation missing"
grep -q 'Current phase: Milestone 1.1' Docs/ROADMAP.md || fail "roadmap was not advanced to Milestone 1.1 candidate"

echo
echo "Milestone 1.1 real-time hot-path repair verification: PASS"
