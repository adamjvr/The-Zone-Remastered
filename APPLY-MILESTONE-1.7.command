#!/bin/zsh
set -euo pipefail

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi

head_hash() {
  git show "HEAD:$1" 2>/dev/null | shasum -a 256 | awk '{print $1}'
}
require_head_hash() {
  local path="$1" expected="$2" actual
  actual="$(head_hash "$path" || true)"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: Milestone 1.7 requires the accepted Milestone 1.6 committed first."
    echo "Mismatch: $path"
    echo "Expected: $expected"
    echo "Actual:   ${actual:-missing}"
    exit 1
  fi
}

require_head_hash ZoneCore/src/zone_core.c a409307b55ddc5df6721f09bcfa31b1c1685d4ae3111d5db12a0354298c9b50d
require_head_hash ZoneCore/include/zone_core.h a856077435ef991c20d97b07bebb23cfae285c7e634d9753fcbed42418b9d358
require_head_hash ZoneCore/tests/test_zone_core.c 42890ff9c2f6524264df4182ae97311adbb90ce45ebcccde15fc675a476460bc

if ! git show HEAD:README.md | grep -q 'Engineering Milestone 1.6'; then
  echo "ERROR: README at HEAD is not Milestone 1.6. Commit the accepted 1.6 tree first."
  exit 1
fi

shasum -a 256 -c FILES.sha256

python3 - <<'PY'
from pathlib import Path

p = Path('README.md')
s = p.read_text()
old_title = '# The Zone Remastered — Engineering Milestone 1.6'
if old_title not in s:
    raise SystemExit('ERROR: expected Milestone 1.6 README title not found')
s = s.replace(old_title, '# The Zone Remastered — Engineering Milestone 1.7', 1)
needle = '## Milestone 1.6 — Shared 80-Slot Capacity & Base Impact Parity\n'
if needle not in s:
    raise SystemExit('ERROR: expected Milestone 1.6 README section not found')
section = '''## Milestone 1.7 — Death, Explosion & Wave Timing Fidelity\n\nMilestone 1.7 replaces the provisional 120-tick respawn and 90-tick wave-clear countdowns with recovered object-lifecycle causality. PPC EXPL handler `0x12080` now drives animation using retained `previous_type`: ship/Mother/HQ explosions advance every other Classic action while ordinary explosions advance every action. Ship respawn occurs only when its recovered 20-frame explosion finishes, and Mother/HQ wave-objective count is decremented only when that transformed explosion is finalized. When the last Mother/HQ finalizes, the next fixed wave begins immediately through the recovered wave-complete relationship; surviving defenders do not gate it.\n\nThe same audit disproves ZoneCore's 90/120 projectile-life values as recovered constants: the original `shot`/`fire` action handlers have no countdown and retire through the spatial/list-maintenance system. Those temporary guards remain explicitly isolated until the pending `+128` spatial/list lift can replace them without inventing immortal wrapped projectiles.\n\nDetailed notes: [`Docs/MILESTONE-1.7.md`](Docs/MILESTONE-1.7.md) and [`Docs/RE-timing-lifecycle.md`](Docs/RE-timing-lifecycle.md).\n\n'''
s = s.replace(needle, section + needle, 1)
p.write_text(s)

p = Path('Docs/ROADMAP.md')
s = p.read_text()
s = s.replace('## Phase 3 — Live Classic gameplay reconstruction — ~74%',
              '## Phase 3 — Live Classic gameplay reconstruction — ~77%', 1)
s = s.replace('**Current phase: Milestone 1.6.**', '**Current phase: Milestone 1.7.**', 1)
old = '''Next priorities:\n\n1. Milestone 1.7 hostile-projectile lifetime, death/respawn, and wave timing fidelity on the display-independent timebase;\n2. Milestone 1.8 wave-transition presentation and procedural waves 19+;\n3. Milestone 1.9 remaining `+128` spatial/list modes, linked-list ordering, collision/destruction/equipment special cases, and Classic RNG parity;\n4. Version 2.0 continuous complete Classic Mode.\n'''
new = '''### Milestone 1.7 — Lifecycle timing fidelity\n\nMilestone 1.7 removes the provisional death/wave countdowns. Ship reset is driven by completion of the recovered 20-frame ship-origin EXPL; Mother/HQ objective count is decremented at explosion finalization; and the next fixed wave begins through the original objective-zero flag path rather than after an invented 90-tick delay. Previous-type-specific EXPL cadence is now live on both Classic and 720-Hz paths.\n\nThe projectile audit also establishes that `shot`/`fire` do not own lifetime counters. Their remaining portable 90/120 retirement guards are explicitly temporary until the `+128` spatial/list-maintenance model is promoted.\n\nNext priorities:\n\n1. Milestone 1.8 procedural Waves 19+ and recovered wave-transition presentation/setup;\n2. Milestone 1.9 `+128` spatial/list modes, projectile retirement, linked-list traversal/slot reuse, and remaining collision/destruction/equipment special cases;\n3. Milestone 2.0 Classic Mac RNG/deterministic compatibility and continuous complete Classic Mode closure.\n'''
if old not in s:
    raise SystemExit('ERROR: expected Milestone 1.6 roadmap priority block not found')
s = s.replace(old, new, 1)
p.write_text(s)
PY

chmod +x APPLY-MILESTONE-1.7.command Tools/verify-milestone-1.7.command Tools/test-zonecore.sh Tools/test-zone-timebase.command Tools/verify-native-targets.command 2>/dev/null || true
./Tools/verify-milestone-1.7.command

echo
echo "Milestone 1.7 candidate applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Play:  ./Tools/run-macos-refresh.command native high"
echo "Test death/respawn and the end of Zone 1 carefully."
echo "Do not commit 1.7 until the play test is accepted."
