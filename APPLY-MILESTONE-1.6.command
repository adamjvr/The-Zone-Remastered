#!/bin/zsh
set -euo pipefail

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi

# Because extracting the ZIP overwrites working-tree files before this script
# runs, validate the committed HEAD tree rather than the current working copy.
head_hash() {
  git show "HEAD:$1" 2>/dev/null | shasum -a 256 | awk '{print $1}'
}
require_head_hash() {
  local path="$1" expected="$2" actual
  actual="$(head_hash "$path" || true)"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: Milestone 1.6 requires the accepted Milestone 1.5 committed first."
    echo "Mismatch: $path"
    echo "Expected: $expected"
    echo "Actual:   ${actual:-missing}"
    exit 1
  fi
}

require_head_hash ZoneCore/src/zone_core.c 11a3d03d418088246a5dbd5544ff6fa66d3c74db5cf21543d5621876127d0e4e
require_head_hash ZoneCore/include/zone_core.h a81ccc9793120ed58c257bd2273164bbdde2a7af57a92c05f4c0fc3404729afd
require_head_hash ZoneCore/tests/test_zone_core.c 1f90a22a8be8624bcdf1a8712d34536988e29b34307038e0a723697f0add6591
require_head_hash Shared/ZoneGameHost.swift 6ff9d81d2338fde5acc3dd9b9bc2b30b2969abec0a9811c43f9069bb4f5a6083

if ! git show HEAD:README.md | grep -q 'Engineering Milestone 1.5'; then
  echo "ERROR: README at HEAD is not Milestone 1.5. Commit the accepted 1.5 tree first."
  exit 1
fi

shasum -a 256 -c FILES.sha256

python3 - <<'PY'
from pathlib import Path

p = Path('README.md')
s = p.read_text()
old_title = '# The Zone Remastered — Engineering Milestone 1.5'
if old_title not in s:
    raise SystemExit('ERROR: expected Milestone 1.5 README title not found')
s = s.replace(old_title, '# The Zone Remastered — Engineering Milestone 1.6', 1)
needle = '## Milestone 1.5 — Native High-Rate Dynamics Phase 1\n'
if needle not in s:
    raise SystemExit('ERROR: expected Milestone 1.5 README section not found')
section = '''## Milestone 1.6 — Shared 80-Slot Capacity & Base Impact Parity\n\nMilestone 1.6 promotes two directly recovered Classic behaviors on top of the accepted 1.5 high-rate dynamics path. First, PPC startup `0x19E0..0x1A34` allocates exactly **80** 150-byte object records, so the ship, world objects, projectiles/fire and explosions now share one 80-slot admission budget instead of independently exhausting ZoneCore's typed arrays. Second, Mother Base/HQ ship collision at PPC `0x174E8` now restores the missing impact-state consequences: Mother motion selector `+86` resets to 0 and both base/ship receive the recovered one-draw feedback semantics while the already-live damage and continuous-velocity exchange remain intact.\n\nThe internal typed arrays are intentionally retained; exact linked-list traversal/slot reuse and the unresolved `+128` alternate collision-search branch remain later parity work. No 720-Hz timing, presentation, audio, RNG, projectile-lifetime or collision-frequency change is made.\n\nDetailed notes: [`Docs/MILESTONE-1.6.md`](Docs/MILESTONE-1.6.md) and [`Docs/RE-object-pool-base-collision.md`](Docs/RE-object-pool-base-collision.md).\n\n'''
s = s.replace(needle, section + needle, 1)
p.write_text(s)

p = Path('Docs/ROADMAP.md')
s = p.read_text()
s = s.replace('## Phase 3 — Live Classic gameplay reconstruction — ~72%',
              '## Phase 3 — Live Classic gameplay reconstruction — ~74%', 1)
s = s.replace('**Current phase: Milestone 1.5.**', '**Current phase: Milestone 1.6.**', 1)
old = '''Next priorities:\n\n1. Milestone 1.6 remaining Mother/HQ collision-state semantics and original shared-object-pool/list parity;\n2. Milestone 1.7 hostile-projectile lifetime, death/respawn, and wave timing fidelity on the new timebase;\n3. Milestone 1.8 wave-transition presentation and procedural waves 19+;\n4. Milestone 1.9 remaining `+128` Bee/Seeker spatial mode, collision/destruction/equipment special cases, and Classic RNG parity;\n5. Version 2.0 continuous complete Classic Mode.\n'''
new = '''### Milestone 1.6 — Shared capacity and base-impact parity\n\nMilestone 1.6 promotes the original **80-object global capacity** as an observable admission rule across the currently implemented ship/world/projectile/explosion categories. It also restores the missing `0x174E8` Mother/HQ impact consequences: the collision latch/feedback semantics and Mother movement-state reset to 0. Classic and 720-Hz paths are regression-tested against the same consequences.\n\nThis is allocator parity phase 1: ZoneCore still uses typed arrays internally, while exact original linked-list traversal, slot-reuse ordering and the `+128` alternate list-collision branch remain explicit follow-up work.\n\nNext priorities:\n\n1. Milestone 1.7 hostile-projectile lifetime, death/respawn, and wave timing fidelity on the display-independent timebase;\n2. Milestone 1.8 wave-transition presentation and procedural waves 19+;\n3. Milestone 1.9 remaining `+128` spatial/list modes, linked-list ordering, collision/destruction/equipment special cases, and Classic RNG parity;\n4. Version 2.0 continuous complete Classic Mode.\n'''
if old not in s:
    raise SystemExit('ERROR: expected Milestone 1.5 roadmap priority block not found')
s = s.replace(old, new, 1)
p.write_text(s)
PY

chmod +x APPLY-MILESTONE-1.6.command Tools/verify-milestone-1.6.command Tools/test-zonecore.sh Tools/test-zone-timebase.command Tools/verify-native-targets.command 2>/dev/null || true
./Tools/verify-milestone-1.6.command

echo
echo "Milestone 1.6 candidate applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Play:  ./Tools/run-macos-refresh.command native high"
echo "Stress object creation/explosions and deliberately collide with a Mother/HQ."
echo "Do not commit 1.6 until the play test is accepted."
