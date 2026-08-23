#!/bin/zsh
set -euo pipefail
BASE="92f4e1912310162992f067c70edb7133412b48ec"

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi
if [[ "$(git rev-parse HEAD)" != "$BASE" ]]; then
  echo "ERROR: Milestone 1.4 requires exact committed Milestone 1.3."
  echo "Expected HEAD: $BASE"
  echo "Actual HEAD:   $(git rev-parse HEAD)"
  exit 1
fi
if [[ ! -f FILES.sha256 ]]; then
  echo "ERROR: FILES.sha256 missing; re-extract the 1.4 ZIP into the repo root."
  exit 1
fi

shasum -a 256 -c FILES.sha256

python3 - <<'PY'
from pathlib import Path

# README: keep all accumulated history and add the new foundation milestone.
p = Path('README.md')
s = p.read_text()
old_title = '# The Zone Remastered — Engineering Milestone 1.3'
if old_title not in s:
    raise SystemExit('ERROR: expected Milestone 1.3 README title not found')
s = s.replace(old_title, '# The Zone Remastered — Engineering Milestone 1.4', 1)
needle = '## Milestone 1.3 — Bee & Seeker State Completion\n'
if needle not in s:
    raise SystemExit('ERROR: expected Milestone 1.3 README section not found')
section = '''## Milestone 1.4 — Display-Independent Timebase & Native-Refresh Presentation\n\nMilestone 1.4 breaks the old one-render-callback/one-game-step coupling. A monotonic **720-Hz master scheduling grid** now drives the host, with one authoritative Classic step every **12 master ticks = 60 Hz**, while Metal presentation requests the active screen's native maximum refresh. 120/144/165/240-Hz presentation therefore no longer changes game speed.\n\nThis is deliberately the foundation, not a fake-smoothing layer: there is no interpolation or extrapolation, and ZoneCore gameplay remains unchanged. The package also adds a headless Wave-18 benchmark for 240/480/720/960/1440-Hz candidate dynamics rates. Continuous motion can be promoted to the high-rate grid only after benchmark and regression evidence justify it.\n\nDetailed notes: [`Docs/MILESTONE-1.4.md`](Docs/MILESTONE-1.4.md) and [`Docs/RE-high-refresh-timebase.md`](Docs/RE-high-refresh-timebase.md).\n\n'''
s = s.replace(needle, section + needle, 1)
p.write_text(s)

# Roadmap: advance 1.4 from planned to active foundation and keep the already
# approved future high-rate-dynamics track explicit.
p = Path('Docs/ROADMAP.md')
s = p.read_text()
old = '**Current phase: Milestone 1.3.**'
if old not in s:
    raise SystemExit('ERROR: expected Milestone 1.3 roadmap marker not found')
s = s.replace(old, '**Current phase: Milestone 1.4.**', 1)
old_intro = '''Milestone 1.4 will decouple simulation time from display presentation without reintroducing interpolation/extrapolation as the foundation. The architecture track is:\n\n- benchmark headless ZoneCore at candidate fixed rates (240/480/720/960/1440 Hz) and select a rate with large minimum-hardware headroom;\n- introduce an integer, monotonic `ZoneTimebase` so a rendered frame is no longer synonymous with one game step;\n- schedule recovered Classic discrete semantics (AI/RNG/fire gates/timers) at their recovered cadence while allowing continuous dynamics to run at the selected high simulation rate;\n- present genuinely fresh simulation state at 60/120/144/165/240+ Hz and VRR/ProMotion rates without changing game speed;\n- preserve Classic TickCount-derived durations, including the Bee/Seeker 60-tick gate, independently of monitor refresh;\n- keep render interpolation/extrapolation optional rather than foundational.\n'''
new_intro = '''Milestone 1.4 establishes the display-independent timebase foundation without reintroducing interpolation/extrapolation. The live architecture now:\n\n- provides a monotonic integer **720-Hz master scheduling grid**;\n- schedules the unchanged authoritative Classic game step every **12 master ticks = 60 Hz**;\n- requests the active macOS/iPadOS screen's native maximum presentation rate, with a diagnostic Hz override;\n- proves 60/120/144/165/240-Hz presentation cannot change Classic game speed;\n- adds an optimized headless ZoneCore benchmark for 240/480/720/960/1440-Hz candidate dynamics rates;\n- preserves Classic TickCount-derived durations independently of monitor refresh;\n- keeps interpolation/extrapolation out of the foundational path.\n\nThe next high-refresh promotion is to decompose continuous dynamics from the monolithic Classic step and move only rate-correct motion/integration onto the master grid. AI/RNG/fire gates/timers remain on recovered cadence.\n'''
if old_intro not in s:
    raise SystemExit('ERROR: expected planned Milestone 1.4 roadmap block not found')
s = s.replace(old_intro, new_intro, 1)
p.write_text(s)
PY

chmod +x \
  Tools/verify-milestone-1.4.command \
  Tools/test-zone-timebase.command \
  Tools/benchmark-zonecore.command \
  Tools/run-macos-refresh.command \
  Tools/run-macos-perf.command \
  Tools/summarize-macos-perf.command \
  Tools/test-zonecore.sh \
  Tools/verify-native-targets.command 2>/dev/null || true

./Tools/verify-milestone-1.4.command

echo
echo "Milestone 1.4 candidate applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Native refresh test: ./Tools/run-macos-refresh.command native"
echo "60-Hz comparison:  ./Tools/run-macos-refresh.command 60"
echo "Headless benchmark: ./Tools/benchmark-zonecore.command"
echo "Do not commit until the native-refresh play test is accepted."
