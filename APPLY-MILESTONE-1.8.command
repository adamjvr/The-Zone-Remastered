#!/bin/zsh
set -euo pipefail

BASE="a4b61fa63db0eddf953829d33b183b358da651e0"

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi

if [[ "$(git rev-parse HEAD)" != "$BASE" ]]; then
  echo "ERROR: Milestone 1.8 requires the accepted Milestone 1.7 commit."
  echo "Expected HEAD: $BASE"
  echo "Actual HEAD:   $(git rev-parse HEAD)"
  exit 1
fi

shasum -a 256 -c FILES.sha256

python3 - <<'PY'
from pathlib import Path
import re

# README: repair the older top-of-file milestone index if necessary, then add
# the product milestone plus compact 1.6/1.7 summaries when earlier packaging
# left those top-level sections behind the engineering work.
p = Path('README.md')
s = p.read_text()
s = re.sub(r'^# The Zone Remastered — Engineering Milestone [^\n]+$',
           '# The Zone Remastered — Engineering Milestone 1.8', s, count=1, flags=re.M)

anchor = '## Milestone 1.5 — Native High-Rate Dynamics Phase 1\n'
if anchor not in s:
    raise SystemExit('ERROR: README insertion anchor (Milestone 1.5) not found')

sections = []
if '## Milestone 1.8 — Native Front-End & Title Screen' not in s:
    sections.append('''## Milestone 1.8 — Native Front-End & Title Screen\n\nMilestone 1.8 turns the Apple engineering harness into a product flow. Native macOS and iPadOS now boot into a shared SwiftUI title screen with an animated recovered 48-frame ship emblem, New Game, Controls, persistent presentation Preferences, Credits, and macOS Quit. New Game constructs a fresh gameplay host; both platforms can return from Pause to the title screen; and `ZONE_BOOT_DIRECT=1` preserves direct engineering boot. ZoneCore, the 720-Hz motion path, Classic decision/collision cadence, Metal renderer, and AVAudioEngine backend are unchanged.\n\nDetailed notes: [`Docs/MILESTONE-1.8.md`](Docs/MILESTONE-1.8.md) and [`Docs/NATIVE-FRONT-END.md`](Docs/NATIVE-FRONT-END.md).\n\n''')
if '## Milestone 1.7 — Death, Explosion & Wave Timing Fidelity' not in s:
    sections.append('''## Milestone 1.7 — Death, Explosion & Wave Timing Fidelity\n\nMilestone 1.7 removes provisional frame-count timing from death and fixed-wave completion. Ship respawn is driven by completion of the recovered 20-frame ship explosion; Mother/HQ objective count falls at transformed-explosion finalization; and the next fixed wave begins through the recovered objective-zero relationship instead of an invented 90-tick delay.\n\n''')
if '## Milestone 1.6 — Shared 80-Slot Capacity & Base Impact Parity' not in s:
    sections.append('''## Milestone 1.6 — Shared 80-Slot Capacity & Base Impact Parity\n\nMilestone 1.6 enforces the recovered shared 80-object admission budget across ship, world bodies, projectiles and explosions, and restores additional Mother/HQ ship-impact consequences including Mother motion-state reset and impact feedback while keeping typed portable storage internally.\n\n''')
if sections:
    s = s.replace(anchor, ''.join(sections) + anchor, 1)
p.write_text(s)

# Roadmap: record 1.6/1.7 completion and the deliberate product-shell pivot.
p = Path('Docs/ROADMAP.md')
s = p.read_text()
s = re.sub(r'## Phase 3 — Live Classic gameplay reconstruction — ~\d+%',
           '## Phase 3 — Live Classic gameplay reconstruction — ~78%', s, count=1)
s = re.sub(r'\*\*(?:Current phase|Current gameplay checkpoint):[^\n]*\*\*',
           '**Current gameplay checkpoint: Milestone 1.7. Native product milestone 1.8 is active in parallel.**',
           s, count=1)
s = s.replace(
    'Remaining platform work includes the planned display-independent high-refresh timebase/presentation track, followed by product/UI polish and iPad device validation.',
    'The display-independent 720-Hz/native-refresh path is now live. Remaining platform work is product/UI polish, save/persistence integration, final iPad validation, and distribution work.'
)

insert_anchor = '\nNext priorities:\n'
if insert_anchor not in s:
    raise SystemExit('ERROR: roadmap Next priorities anchor not found')
extra = ''
if '### Milestone 1.6 — Shared 80-slot object admission' not in s:
    extra += '''\n### Milestone 1.6 — Shared 80-slot object admission and base-impact parity\n\nThe portable typed stores now obey the recovered global 80-object admission budget, and dedicated Mother/HQ ship-impact state/feedback consequences are regression-covered without altering the accepted high-rate presentation architecture.\n'''
if '### Milestone 1.7 — Recovered lifecycle timing' not in s:
    extra += '''\n### Milestone 1.7 — Recovered lifecycle timing\n\nDeath and wave progression now follow recovered explosion-finalization causality rather than provisional countdowns: the 20-frame ship-origin EXPL drives respawn, and the final Mother/HQ-origin EXPL drives objective-zero wave advancement. Projectile 90/120 lifetime guards remain explicitly temporary pending spatial/list parity.\n'''
if '### Milestone 1.8 — Native Front-End & Title Screen' not in s:
    extra += '''\n### Milestone 1.8 — Native Front-End & Title Screen\n\nThe Apple products now boot through a shared native title shell instead of directly into gameplay. New Game, Controls, persistent presentation Preferences, Credits, macOS Quit, and Return-to-Title pause flow are live; the recovered 48-frame ship bank supplies the title emblem. `ZONE_BOOT_DIRECT=1` retains direct engineering boot, and ZoneCore/high-refresh/audio behavior is deliberately unchanged.\n'''
if extra:
    s = s.replace(insert_anchor, extra + insert_anchor, 1)

# Replace the current priority list regardless of whether the 1.7 packaging
# already rewrote it.
s = re.sub(
    r'Next priorities:\n\n(?:\d+\.[^\n]*\n)+',
    '''Next priorities:\n\n1. Milestone 1.9 `+128` spatial/list parity and recovered projectile retirement;\n2. Milestone 2.0 procedural Waves 19+ plus remaining collision/destruction/equipment behavior;\n3. native Continue/save-slot and Hall of Fame screens on the new front-end shell;\n4. Classic Mac RNG/deterministic compatibility and continuous Classic Mode closure.\n''',
    s,
    count=1,
)

# Product/UI phase becomes a real active workstream.
phase5 = re.compile(r'## Phase 5 — Native product/UI layer — ~\d+%.*?(?=\n## Phase 6 —)', re.S)
replacement = '''## Phase 5 — Native product/UI layer — ~48%\n\n**Status: active in parallel with Classic gameplay reconstruction.**\n\nCompleted foundations:\n\n- SwiftUI/AppKit/UIKit shells;\n- Metal game view;\n- controller abstraction;\n- macOS app branding/icon;\n- macOS pause menu with persistent keyboard remapping and Classic-default reset;\n- shared native title/menu shell on macOS and iPadOS;\n- functional New Game / Controls / Preferences / Credits flows;\n- persistent HUD/control-overlay presentation preferences;\n- Return-to-Title pause flow on macOS and iPadOS;\n- direct developer boot retained through `ZONE_BOOT_DIRECT=1`.\n\nRemaining:\n\n- Continue/save-slot UI and ZoneCore save restoration;\n- Hall of Fame UI;\n- full recovered Classic preferences;\n- game-over/wave-transition presentation;\n- controller-remapping UI;\n- final iPad touch layout/polish;\n- fullscreen/window/display controls;\n- distribution/signing/notarization/App Store work.\n'''
if not phase5.search(s):
    raise SystemExit('ERROR: roadmap Phase 5 block not found')
s = phase5.sub(replacement, s, count=1)
p.write_text(s)
PY

chmod +x APPLY-MILESTONE-1.8.command Tools/verify-milestone-1.8.command 2>/dev/null || true
./Tools/verify-milestone-1.8.command

echo
echo "Milestone 1.8 candidate applied and verified."
echo "Build macOS: ./Tools/build-macos.command"
echo "Run title:    ./Tools/run-macos-refresh.command native high"
echo "Direct boot:  ZONE_BOOT_DIRECT=1 ./Tools/run-macos-refresh.command native high"
echo "Build iPad:   ./Tools/build-ipados-simulator.command"
echo "Do not commit 1.8 until the front-end play test is accepted."
