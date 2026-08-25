#!/bin/zsh
set -euo pipefail
BASE="e0c94d0ac9a50b3006302a47711be2eda7019531"

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi
if [[ "$(git rev-parse HEAD)" != "$BASE" ]]; then
  echo "ERROR: Milestone 1.5 requires exact committed Milestone 1.4."
  echo "Expected HEAD: $BASE"
  echo "Actual HEAD:   $(git rev-parse HEAD)"
  exit 1
fi
if [[ ! -f FILES.sha256 ]]; then
  echo "ERROR: FILES.sha256 missing; re-extract the 1.5 ZIP into the repo root."
  exit 1
fi

shasum -a 256 -c FILES.sha256

python3 - <<'PY'
from pathlib import Path

p = Path('README.md')
s = p.read_text()
old_title = '# The Zone Remastered — Engineering Milestone 1.4'
if old_title not in s:
    raise SystemExit('ERROR: expected Milestone 1.4 README title not found')
s = s.replace(old_title, '# The Zone Remastered — Engineering Milestone 1.5', 1)
needle = '## Milestone 1.4 — Display-Independent Timebase & Native-Refresh Presentation\n'
if needle not in s:
    raise SystemExit('ERROR: expected Milestone 1.4 README section not found')
section = '''## Milestone 1.5 — Native High-Rate Dynamics Phase 1\n\nMilestone 1.5 moves real player, world-object, and projectile position integration onto the **720-Hz master grid**. Recovered decisions remain on the **60-Hz Classic cadence**: input/thrust decisions, AI, RNG/fire gates, timers, exact-pixel collision, projectile lifetime, wave lifecycle, and explosion aging are not multiplied by display refresh. Twelve master substeps land on the same Classic boundary while 120/144/165/240-Hz displays can observe genuinely new ZoneCore positions between those boundaries.\n\nThe old `zone_game_step()` remains unchanged as the deterministic Classic reference. Native high-rate motion is the default host path; `Tools/run-macos-refresh.command ... classic` selects the accepted 1.4 path for direct A/B testing. No interpolation or extrapolation is introduced.\n\nDetailed notes: [`Docs/MILESTONE-1.5.md`](Docs/MILESTONE-1.5.md) and [`Docs/RE-high-rate-dynamics.md`](Docs/RE-high-rate-dynamics.md).\n\n'''
s = s.replace(needle, section + needle, 1)
p.write_text(s)

p = Path('Docs/ROADMAP.md')
s = p.read_text()
s = s.replace('## Phase 3 — Live Classic gameplay reconstruction — ~70%',
              '## Phase 3 — Live Classic gameplay reconstruction — ~72%', 1)
s = s.replace('**Current phase: Milestone 1.4.**', '**Current phase: Milestone 1.5.**', 1)
old = '''The next high-refresh promotion is to decompose continuous dynamics from the monolithic Classic step and move only rate-correct motion/integration onto the master grid. AI/RNG/fire gates/timers remain on recovered cadence.\n\nNext priorities:\n\n1. Milestone 1.4 display-independent timebase and high-refresh simulation/presentation architecture;\n2. remaining Mother/HQ collision-state and original object-list/shared-capacity parity details;\n3. hostile-projectile lifetime, death/respawn, and wave timing fidelity on the new timebase;\n4. wave-transition presentation and procedural waves 19+;\n5. remaining `+128` Bee/Seeker spatial mode, collision/destruction/equipment special cases, and Classic RNG parity.\n'''
new = '''### Milestone 1.5 — Native high-rate dynamics\n\nMilestone 1.5 promotes continuous motion onto the already-proven 720-Hz master grid while preserving the 60-Hz Classic rule boundary:\n\n- player, world-object and projectile positions receive real 1/720-second integration updates;\n- each master displacement is exactly 1/12 of the recovered per-Classic-step displacement;\n- input/thrust decisions, AI, RNG/fire gates, object ticks and animation decisions remain once per Classic interval;\n- exact-pixel collision, projectile lifetime, pickups, impact damage, wave lifecycle and explosion aging remain on the Classic end boundary;\n- `zone_game_step()` remains unchanged as the deterministic Classic reference API;\n- new regressions compare one Classic interval against twelve master ticks and run a 180-interval changing-input parity trace;\n- the host retains an explicit Classic/high dynamics A/B switch; interpolation and extrapolation remain absent.\n\nThis completes the first genuine high-refresh dynamics promotion. High-rate collision remains a separate Remastered-policy question because changing collision sampling frequency can change observable Classic outcomes.\n\nNext priorities:\n\n1. Milestone 1.6 remaining Mother/HQ collision-state semantics and original shared-object-pool/list parity;\n2. Milestone 1.7 hostile-projectile lifetime, death/respawn, and wave timing fidelity on the new timebase;\n3. Milestone 1.8 wave-transition presentation and procedural waves 19+;\n4. Milestone 1.9 remaining `+128` Bee/Seeker spatial mode, collision/destruction/equipment special cases, and Classic RNG parity;\n5. Version 2.0 continuous complete Classic Mode.\n'''
if old not in s:
    raise SystemExit('ERROR: expected Milestone 1.4 roadmap tail not found')
s = s.replace(old, new, 1)
p.write_text(s)
PY

chmod +x APPLY-MILESTONE-1.5.command Tools/verify-milestone-1.5.command Tools/run-macos-refresh.command Tools/run-macos-perf.command Tools/benchmark-zonecore.command Tools/test-zonecore.sh Tools/test-zone-timebase.command Tools/verify-native-targets.command 2>/dev/null || true
./Tools/verify-milestone-1.5.command

echo
echo "Milestone 1.5 candidate applied and verified."
echo "Build:        ./Tools/build-macos.command"
echo "Classic A/B:  ./Tools/run-macos-refresh.command 60 classic"
echo "High @ 60:    ./Tools/run-macos-refresh.command 60 high"
echo "Native/high:  ./Tools/run-macos-refresh.command native high"
echo "Do not commit until the high-rate motion play test is accepted."
