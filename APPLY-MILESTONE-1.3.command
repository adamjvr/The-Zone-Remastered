#!/bin/zsh
set -euo pipefail
BASE="f7894f0b8a28a2016fe6f593585fd4ecd335ad42"

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi
if [[ "$(git rev-parse HEAD)" != "$BASE" ]]; then
  echo "ERROR: Milestone 1.3 requires exact committed Milestone 1.2."
  echo "Expected HEAD: $BASE"
  echo "Actual HEAD:   $(git rev-parse HEAD)"
  exit 1
fi
if [[ ! -f FILES.sha256 ]]; then
  echo "ERROR: FILES.sha256 missing; re-extract the 1.3 ZIP into the repo root."
  exit 1
fi

shasum -a 256 -c FILES.sha256

python3 - <<'PY'
from pathlib import Path

# Advance README without replacing the accumulated milestone history.
p = Path('README.md')
s = p.read_text()
old_title = '# The Zone Remastered — Engineering Milestone 1.2'
if old_title not in s:
    raise SystemExit('ERROR: expected Milestone 1.2 README title not found')
s = s.replace(old_title, '# The Zone Remastered — Engineering Milestone 1.3', 1)
needle = '## Milestone 1.2 — Host Stall Attribution\n'
if needle not in s:
    raise SystemExit('ERROR: expected Milestone 1.2 README section not found')
section = '''## Milestone 1.3 — Bee & Seeker State Completion\n\nMilestone 1.3 returns to Classic gameplay reconstruction on the accepted 1.2 runtime. Bee PPC `0x154A8` and Seeker PPC `0x15944` now honor their recovered `+66/+92` timed hit-state gates: while elapsed Classic TickCount is below **60**, they retain existing motion and skip retarget/facing/fire; at elapsed 60 the state clears and normal behavior resumes. The Seeker player/body collision path at `0x1A0B4..0x1A0C8` backdates `+92` by **30**, leaving half of the full interval after contact.\n\nThe earlier roadmap description of a Bee "return" state is corrected: the Bee handler does not read its donor link and contains no recovered return-to-parent navigation. Professional Wave 2 now supplies a real fixed-wave integration regression proving that a nonlethal hit on one Mother can request a Bee from the other Mother, while Wave 1 still correctly cannot self-donate.\n\nDetailed notes: [`Docs/MILESTONE-1.3.md`](Docs/MILESTONE-1.3.md) and [`Docs/RE-bee-seeker.md`](Docs/RE-bee-seeker.md).\n\n'''
s = s.replace(needle, section + needle, 1)
p.write_text(s)

# Advance/revise roadmap, including the already-approved high-refresh track.
p = Path('Docs/ROADMAP.md')
s = p.read_text()
s = s.replace('## Phase 3 — Live Classic gameplay reconstruction — ~68%',
              '## Phase 3 — Live Classic gameplay reconstruction — ~70%', 1)
old = '''**Current phase: Milestone 1.2.**\n\nMilestone 1.2 is an instrumentation-only attribution phase on the accepted 1.1 build. It keeps ZoneCore and ZoneRenderer unchanged while measuring input, core simulation, audio drain, individual audio start, and HUD work independently so the remaining intermittent native stall can be repaired without another global timing change.\n'''
new = '''**Current phase: Milestone 1.3.**\n\nMilestone 1.3 completes the recovered Bee/Seeker timed hit-state behavior currently supported by the portable object model. Bee and Seeker now honor their 60-TickCount `+66/+92` coast gates; Seeker player collision applies the recovered 30-tick timestamp backdate; and Professional Wave 2 regression-tests a real other-Mother Bee donor. The earlier "Bee return" roadmap wording is corrected because PPC `0x154A8` contains no parent-return state.\n\nMilestone 1.2 is an instrumentation-only attribution phase on the accepted 1.1 build. It keeps ZoneCore and ZoneRenderer unchanged while measuring input, core simulation, audio drain, individual audio start, and HUD work independently so the remaining intermittent native stall can be repaired without another global timing change.\n'''
if old not in s:
    raise SystemExit('ERROR: expected Milestone 1.2 roadmap marker not found')
s = s.replace(old, new, 1)
s = s.replace('- Bee stun/return edge states around the now-live continuous-vector chase;\n',
              '- unresolved Bee/Seeker `+128` spatial-mode behavior around the now-live chase/hit-state handlers;\n', 1)

next_old = '''Next priorities:\n\n1. complete Bee stun/return and remaining Seeker edge states around the now-live pursuit cores;\n2. finish remaining Mother/HQ collision-state and original object-list/shared-capacity parity details;\n3. finish hostile-projectile lifetime and special collision consequences;\n4. complete wave-transition presentation and procedural waves 19+;\n5. remaining collision/destruction/equipment special cases.\n'''
next_new = '''### Milestone 1.4 — High-refresh engine/timebase foundation\n\nMilestone 1.4 will decouple simulation time from display presentation without reintroducing interpolation/extrapolation as the foundation. The architecture track is:\n\n- benchmark headless ZoneCore at candidate fixed rates (240/480/720/960/1440 Hz) and select a rate with large minimum-hardware headroom;\n- introduce an integer, monotonic `ZoneTimebase` so a rendered frame is no longer synonymous with one game step;\n- schedule recovered Classic discrete semantics (AI/RNG/fire gates/timers) at their recovered cadence while allowing continuous dynamics to run at the selected high simulation rate;\n- present genuinely fresh simulation state at 60/120/144/165/240+ Hz and VRR/ProMotion rates without changing game speed;\n- preserve Classic TickCount-derived durations, including the Bee/Seeker 60-tick gate, independently of monitor refresh;\n- keep render interpolation/extrapolation optional rather than foundational.\n\nNext priorities:\n\n1. Milestone 1.4 display-independent timebase and high-refresh simulation/presentation architecture;\n2. remaining Mother/HQ collision-state and original object-list/shared-capacity parity details;\n3. hostile-projectile lifetime, death/respawn, and wave timing fidelity on the new timebase;\n4. wave-transition presentation and procedural waves 19+;\n5. remaining `+128` Bee/Seeker spatial mode, collision/destruction/equipment special cases, and Classic RNG parity.\n'''
if next_old not in s:
    raise SystemExit('ERROR: expected roadmap next-priorities block not found')
s = s.replace(next_old, next_new, 1)

s = s.replace('Remaining platform work is primarily product/UI polish and iPad device validation, not architectural restructuring.',
              'Remaining platform work includes the planned display-independent high-refresh timebase/presentation track, followed by product/UI polish and iPad device validation.', 1)
p.write_text(s)
PY

chmod +x Tools/verify-milestone-1.3.command Tools/test-zonecore.sh Tools/verify-native-targets.command 2>/dev/null || true
./Tools/verify-milestone-1.3.command

echo
echo "Milestone 1.3 candidate applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Play through Zone 1 into Zone 2; hit a Wave-2 Mother and look for the Bee from the other Mother."
echo "Do not commit until the play test is accepted."
