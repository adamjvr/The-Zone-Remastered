#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi

# Milestone installers verify the accepted content, not a magic HEAD SHA.
# This remains valid if an equivalent-content checkpoint has a different
# commit identity.
head_hash() {
  /usr/bin/git show "HEAD:$1" 2>/dev/null | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'
}
require_head_hash() {
  local file_path="$1" expected="$2" actual
  actual="$(head_hash "$file_path" || true)"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: committed base does not match accepted Milestone 1.9."
    echo "Mismatch: $file_path"
    echo "Expected: $expected"
    echo "Actual:   ${actual:-missing}"
    exit 1
  fi
}

require_head_hash ZoneCore/src/zone_core.c 4f7ee078d0390b4ed62e4553aa51458fbb84a5d97ade134f3d98f659f39629c1
require_head_hash ZoneCore/include/zone_core.h 1167504e47e4ef8e09fcaae81f239d2025da155c430d8ebc436e1c2d79aa8ab9
require_head_hash ZoneCore/tests/test_zone_core.c e17bc43e9c00b7dc8b88008c2006741ddbf91c018b3683a70bfc1639a6ef680e
require_head_hash Docs/MILESTONE-1.9.md f543c64f8fea09d704afe275f2cdb944690129eaa8c581cf8380bc71ee4d95d4
require_head_hash Docs/RE-projectile-spatial.md e5a8f49c0e88b3af41bba2d920db617cd536d127e5801754fc76b78f42fcace0

if ! /usr/bin/git show HEAD:README.md | /usr/bin/grep -q 'Engineering Milestone 1.9'; then
  echo "ERROR: committed README does not identify the accepted Milestone 1.9 checkpoint."
  exit 1
fi
if ! /usr/bin/git show HEAD:Docs/ROADMAP.md | /usr/bin/grep -q '### Milestone 1.9 — Recovered projectile spatial retirement'; then
  echo "ERROR: committed roadmap does not contain the accepted Milestone 1.9 checkpoint."
  exit 1
fi

# The archive has already overlaid the 1.10 payload by the time this script is
# launched. Refuse unrelated local changes, but allow exactly the payload files.
/usr/bin/python3 - <<'PY'
import subprocess

allowed = {
    'APPLY-MILESTONE-1.10.command',
    'FILES.sha256',
    'MILESTONE-1.10-MANIFEST.txt',
    'Docs/MILESTONE-1.10.md',
    'Docs/RE-object-list-slot-order.md',
    'Tools/verify-milestone-1.10.command',
    'ZoneCore/include/zone_core.h',
    'ZoneCore/src/zone_core.c',
    'ZoneCore/tests/test_zone_core.c',
}
raw = subprocess.check_output(['/usr/bin/git', 'status', '--porcelain=v1', '-z'])
records = [r for r in raw.split(b'\0') if r]
unexpected = []
i = 0
while i < len(records):
    rec = records[i]
    if len(rec) < 4:
        unexpected.append(rec.decode('utf-8', 'replace'))
        i += 1
        continue
    status = rec[:2].decode('ascii', 'replace')
    name = rec[3:].decode('utf-8', 'replace')
    if name not in allowed:
        unexpected.append(f'{status} {name}')
    if status[0] in 'RC' or status[1] in 'RC':
        i += 1
        if i < len(records):
            unexpected.append('rename/copy target ' + records[i].decode('utf-8', 'replace'))
    i += 1
if unexpected:
    print('ERROR: unrelated local changes are present; refusing to apply 1.10:')
    for item in unexpected:
        print('  ' + item)
    raise SystemExit(1)
PY

/usr/bin/shasum -a 256 -c FILES.sha256

/usr/bin/python3 - <<'PY'
from pathlib import Path

# README promotion is idempotent so a rerun after a failed verification does
# not duplicate sections.
p = Path('README.md')
s = p.read_text()
old_title = '# The Zone Remastered — Engineering Milestone 1.9'
new_title = '# The Zone Remastered — Engineering Milestone 1.10'
if new_title not in s:
    if old_title not in s:
        raise SystemExit('ERROR: expected Milestone 1.9 README title not found')
    s = s.replace(old_title, new_title, 1)

heading_19 = '## Milestone 1.9 — Recovered Projectile Spatial Retirement\n'
if heading_19 not in s:
    raise SystemExit('ERROR: expected Milestone 1.9 README section not found')
if '## Milestone 1.10 — Shared Object Slots & +138 List Fidelity' not in s:
    section = '''## Milestone 1.10 — Shared Object Slots & +138 List Fidelity

Milestone 1.10 promotes the exact recovered 80-record allocator and `+138` object-chain ordering. The persistent player/head is Classic slot 0; mode 0 allocates low-to-high and inserts immediately after the head, while mode 1 allocates high-to-low and appends at the list tail. Player shots and Headquarters fire use the low mode; fixed/world objects and moving-enemy fire use the high mode. Ship/world destruction now transforms the same Classic record into `EXPL`, preserving slot identity and list position until finalization, and known first-match Bee/Mother scans follow Classic list order instead of typed-array order.

Reverse engineering in this phase also identifies object byte `+129` as coarse spatial-cell registration. Full non-projectile `+128/+129` behavior remains deferred until the original camera/world-to-screen transform is restored rather than guessed.

Detailed notes: [`Docs/MILESTONE-1.10.md`](Docs/MILESTONE-1.10.md) and [`Docs/RE-object-list-slot-order.md`](Docs/RE-object-list-slot-order.md).

'''
    s = s.replace(heading_19, section + heading_19, 1)
p.write_text(s)

# Roadmap promotion. Replace the priorities section structurally rather than
# depending on every previous bullet remaining byte-identical.
p = Path('Docs/ROADMAP.md')
s = p.read_text()
s = s.replace('## Phase 3 — Live Classic gameplay reconstruction — ~81%',
              '## Phase 3 — Live Classic gameplay reconstruction — ~84%', 1)
s = s.replace('**Current gameplay checkpoint: Milestone 1.9. Native product checkpoint 1.8.1 is accepted in parallel.**',
              '**Current gameplay checkpoint: Milestone 1.10. Native product checkpoint 1.8.1 is accepted in parallel.**', 1)
s = s.replace('- remaining Mother Base/HQ collision/state edge semantics and original shared-object-pool behavior;',
              '- remaining Mother Base/HQ collision/state edge semantics;', 1)
s = s.replace('- unresolved Bee/Seeker `+128` spatial-mode behavior around the now-live chase/hit-state handlers;',
              '- original camera/world-to-screen transform plus remaining Bee/Seeker `+128/+129` spatial-mode behavior;', 1)

if '### Milestone 1.10 — Shared Object Slots & +138 List Fidelity' not in s:
    anchor = 'Next priorities:\n'
    if anchor not in s:
        raise SystemExit('ERROR: roadmap priorities anchor not found')
    section = '''### Milestone 1.10 — Shared Object Slots & +138 List Fidelity

The portable core now tracks the recovered 80-record allocator identity and global `+138` object chain in addition to typed portable stores. The player remains persistent head/slot 0; low mode scans 0→79 and inserts after the head; high mode scans 79→0 and appends at the tail; unlink frees the exact record for directional reuse. Player shots/HQ fire and fixed/moving-object paths now use their recovered modes. Ship and world destruction transform the same Classic record into `EXPL`, preserving slot/list identity, and Bee-donor/mobile-Mother first-match scans follow recovered list order. `+129` is decoded as coarse spatial-cell registration, but live world `+128/+129` is intentionally deferred until the original camera/world-to-screen transform is restored.

'''
    s = s.replace(anchor, section + anchor, 1)

start = s.find('Next priorities:\n')
end = s.find('\n## Phase 4 —', start)
if start < 0 or end < 0:
    raise SystemExit('ERROR: could not locate roadmap priorities block')
priorities = '''Next priorities:

1. Milestone 1.11 — recover the original camera/world-to-screen transform, then promote non-projectile `+128/+129` live-region and coarse spatial-cell state including Bee/Seeker edges;
2. Milestone 2.0 — finish remaining Classic collision/destruction/equipment behavior on the recovered object/spatial foundation;
3. Milestone 2.1 — recover procedural Waves 19+;
4. Milestone 2.2+ — Classic Mac RNG compatibility, save/load + Hall of Fame, then continuous Classic Mode closure.
'''
s = s[:start] + priorities + s[end:]
p.write_text(s)
PY

/bin/chmod +x APPLY-MILESTONE-1.10.command Tools/verify-milestone-1.10.command
./Tools/verify-milestone-1.10.command

echo
echo "Milestone 1.10 candidate applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Play:  ./Tools/run-macos-refresh.command native high"
echo "iPad hardware: open TheZoneRemastered.xcodeproj, select The Zone iPadOS + tethered iPad Pro, then Cmd-R."
echo "Do not commit 1.10 until the allocator/list and combat behavior pass hardware play-testing."
