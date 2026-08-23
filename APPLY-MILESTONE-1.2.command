#!/bin/zsh
set -euo pipefail
BASE="e3bdbbcf5d04672da2de4ce738669394bdb5b66c"

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi

if [[ "$(git rev-parse HEAD)" != "$BASE" ]]; then
  echo "ERROR: Milestone 1.2 is based on exact committed Milestone 1.1."
  echo "Expected HEAD: $BASE"
  echo "Actual HEAD:   $(git rev-parse HEAD)"
  exit 1
fi

if [[ ! -f FILES.sha256 ]]; then
  echo "ERROR: FILES.sha256 missing; re-extract the milestone ZIP into the repo root."
  exit 1
fi
shasum -a 256 -c FILES.sha256

# Advance high-level documentation without replacing the historical sections.
python3 - <<'PY'
from pathlib import Path

readme = Path('README.md')
s = readme.read_text()
if '# The Zone Remastered — Engineering Milestone 1.2' not in s:
    s = s.replace('# The Zone Remastered — Engineering Milestone 1.0',
                  '# The Zone Remastered — Engineering Milestone 1.2', 1)

if '## Milestone 1.2 — Host Stall Attribution' not in s:
    marker = '## Milestone 1.0 — Rotor Orbit, Attack & Return AI'
    block = '''## Milestone 1.2 — Host Stall Attribution\n\nMilestone 1.2 keeps the accepted 1.1 gameplay/rendering behavior unchanged and splits remaining slow `host.step()` frames into input, ZoneCore, audio-drain, audio-trigger, and HUD stages. Audio triggers are independently split into player rewind and `AVAudioPlayer.play()` timing. The diagnostic runner now prints an automatic compact summary after each perf session.\n\nDetailed notes: [`Docs/MILESTONE-1.2.md`](Docs/MILESTONE-1.2.md).\n\n## Milestone 1.1 — Real-Time Hot-Path Repair\n\nMilestone 1.1 removed synchronous sprite texture construction and per-event audio-player construction from active gameplay while preserving the Milestone 1.0 ZoneCore/60-Hz host contract. Extended play testing successfully cleared Zone 1 with all 651 sprite textures preloaded and no observed texture-cache misses or 16-voice-bank exhaustion.\n\nDetailed notes: [`Docs/MILESTONE-1.1.md`](Docs/MILESTONE-1.1.md).\n\n'''
    if marker not in s:
        raise SystemExit('ERROR: README Milestone 1.0 insertion marker not found')
    s = s.replace(marker, block + marker, 1)
readme.write_text(s)

roadmap = Path('Docs/ROADMAP.md')
r = roadmap.read_text()
if '**Current phase: Milestone 1.2.**' not in r:
    old = '**Current phase: Milestone 1.1.**'
    new = '''**Current phase: Milestone 1.2.**\n\nMilestone 1.2 is an instrumentation-only attribution phase on the accepted 1.1 build. It keeps ZoneCore and ZoneRenderer unchanged while measuring input, core simulation, audio drain, individual audio start, and HUD work independently so the remaining intermittent native stall can be repaired without another global timing change.'''
    if old not in r:
        raise SystemExit('ERROR: expected Milestone 1.1 roadmap marker not found')
    r = r.replace(old, new, 1)
roadmap.write_text(r)
PY

chmod +x \
  Tools/run-macos-perf.command \
  Tools/summarize-macos-perf.command \
  Tools/test-perf-summary.command \
  Tools/verify-milestone-1.2.command \
  Tools/test-zonecore.sh \
  Tools/verify-native-targets.command 2>/dev/null || true

./Tools/verify-milestone-1.2.command

echo
echo "Milestone 1.2 applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Profile: ./Tools/run-macos-perf.command"
echo "The perf runner will print a compact attribution summary when the app exits."
