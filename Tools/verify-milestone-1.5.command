#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
BASE="e0c94d0ac9a50b3006302a47711be2eda7019531"
EXPECTED_CLASSIC_STEP_SHA="a6c06aeb8683229a3b2637a8e875fc2a8f92141b38f0ea90d2685ff33b974c79"

if [[ "$(git rev-parse HEAD)" != "$BASE" ]]; then
  echo "ERROR: Milestone 1.5 verification requires committed Milestone 1.4."
  echo "Expected HEAD: $BASE"
  echo "Actual HEAD:   $(git rev-parse HEAD)"
  exit 1
fi

# Guard all subsystems that this milestone must not touch.
git diff --quiet "$BASE" -- Shared/ZoneAudioEngine.swift Shared/ZoneRenderer.swift Shared/ZoneMetalView.swift || {
  echo "ERROR: 1.5 must not modify accepted audio/renderer/Metal-view code."
  exit 1
}
git diff --quiet "$BASE" -- ZoneCore/Recovered/src/ai.c ZoneCore/Recovered/src/collision.c ZoneCore/Recovered/src/player.c ZoneCore/Recovered/src/waves.c ZoneCore/Recovered/src/damage.c ZoneCore/Recovered/src/objects.c || {
  echo "ERROR: 1.5 must not alter recovered behavior/collision tables."
  exit 1
}

grep -q '#define ZONE_MASTER_HZ 720u' ZoneCore/include/zone_core.h
grep -q '#define ZONE_CLASSIC_HZ 60u' ZoneCore/include/zone_core.h
grep -q 'zone_game_advance_master_ticks' ZoneCore/include/zone_core.h
grep -q 'Milestone 1.5 native high-rate path' ZoneCore/src/zone_core.c
grep -q 'highRateDynamicsEnabled.*!= "0"' Shared/ZoneGameHost.swift
grep -q '720-Hz real motion / 60-Hz Classic decisions+collision' Tools/run-macos-refresh.command
grep -q 'native dynamics events:' Tools/summarize-macos-perf.command
grep -q 'Classic/native-dynamics benchmark' Tools/zonecore-benchmark.c
grep -q 'case TZ_TYPE_RAID:' ZoneCore/Recovered/src/ai.c
grep -q 'AVAudioPlayerNode' Shared/ZoneAudioEngine.swift

python3 - <<PY
from pathlib import Path
import hashlib
p = Path('ZoneCore/src/zone_core.c')
s = p.read_text()
start = s.index('void zone_game_step(ZoneGame *g, ZoneInput in) {')
end = s.index('\n/* Milestone 1.5 native high-rate path.', start)
digest = hashlib.sha256(s[start:end].encode()).hexdigest()
expected = '$EXPECTED_CLASSIC_STEP_SHA'
if digest != expected:
    raise SystemExit(f'ERROR: legacy zone_game_step changed: {digest} != {expected}')
print('Classic zone_game_step preservation: PASS')
PY

# New tests are part of the ordinary ZoneCore suite, so all old fidelity tests
# and the high-rate parity tests must pass together.
./Tools/test-zonecore.sh
./Tools/test-zone-timebase.command
./Tools/benchmark-zonecore.command 1200

# Verify the enhanced performance summarizer understands native dynamics.
TMP_LOG="$(mktemp -t zone15-summary).log"
trap 'rm -f "$TMP_LOG"' EXIT
cat > "$TMP_LOG" <<'LOG'
[ZonePerf][renderer] presentation requestedFPS=240
[ZonePerf][dynamics] mode=720Hz-real-motion classicBoundary=60Hz
[ZonePerf][dynamics] frame=12 masterTicks=3 classicSteps=0 phase=3 core=0.012 clamped=0
LOG
SUMMARY="$(./Tools/summarize-macos-perf.command "$TMP_LOG")"
echo "$SUMMARY" | grep -q 'requested presentation: 240 Hz'
echo "$SUMMARY" | grep -q 'native dynamics events: 1'
echo "$SUMMARY" | grep -q 'max master ticks/present: 3'
rm -f "$TMP_LOG"
trap - EXIT

grep -q '# The Zone Remastered — Engineering Milestone 1.5' README.md
grep -q 'Current phase: Milestone 1.5' Docs/ROADMAP.md
grep -q 'Milestone 1.5 — Native high-rate dynamics' Docs/ROADMAP.md

swiftc -parse Shared/ZoneGameHost.swift Shared/ZoneRenderer.swift Shared/ZoneMetalView.swift Shared/ZoneAudioEngine.swift
zsh -n APPLY-MILESTONE-1.5.command Tools/run-macos-refresh.command Tools/run-macos-perf.command Tools/verify-milestone-1.5.command
sh -n Tools/summarize-macos-perf.command Tools/benchmark-zonecore.command
git diff --check
./Tools/verify-native-targets.command

echo "Milestone 1.5 verification: PASS"
