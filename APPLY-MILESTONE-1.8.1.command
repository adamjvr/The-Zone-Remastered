#!/bin/zsh
set -euo pipefail

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi

BASE_SHA="7064192e475b39fd85cc45167637ad3b43d7bbcd"
if [[ "$(git rev-parse HEAD)" != "$BASE_SHA" ]]; then
  echo "ERROR: Milestone 1.8.1 requires the accepted Milestone 1.8 commit."
  echo "Expected HEAD: $BASE_SHA"
  echo "Actual HEAD:   $(git rev-parse HEAD)"
  exit 1
fi

protected=(
  ZoneCore
  Shared/ZoneGameHost.swift
  Shared/ZoneRenderer.swift
  Shared/ZoneMetalView.swift
  Shared/ZoneAudioEngine.swift
  Shared/ZoneInputRouter.swift
  Shared/ZoneControllerManager.swift
  Shared/ZoneTouchControls.swift
  project.yml
  TheZoneRemastered.xcodeproj
)
for path in $protected; do
  if ! git diff --quiet HEAD -- "$path"; then
    echo "ERROR: protected gameplay/runtime path already has local changes: $path"
    echo "Commit/stash/review those changes before applying 1.8.1."
    exit 1
  fi
done

shasum -a 256 -c FILES.sha256

python3 - <<'PY'
from pathlib import Path

p = Path('README.md')
s = p.read_text()
old_title = '# The Zone Remastered — Engineering Milestone 1.8'
if old_title not in s:
    raise SystemExit('ERROR: expected Milestone 1.8 README title not found')
s = s.replace(old_title, '# The Zone Remastered — Engineering Milestone 1.8.1', 1)
needle = '## Milestone 1.8 — Native Front-End & Title Screen\n'
if needle not in s:
    raise SystemExit('ERROR: expected Milestone 1.8 README section not found')
section = '''## Milestone 1.8.1 — Front-End Polish & Navigation\n\nMilestone 1.8.1 turns the accepted title shell into a controller-first game front end. D-pad/left-stick selection, primary-button activation, secondary/Menu back behavior, focused hardware-key navigation, controller-operable Preferences, and controller-operable iPad Pause are now live. Selection has an explicit visual state, title/subpages respect iPad safe areas, screen transitions and pause styling are unified, and the recovered 48-frame ship remains the visual centerpiece. ZoneCore, the 720-Hz dynamics path, Classic decision/collision cadence, Metal renderer, AVAudioEngine backend, and gameplay input router remain unchanged.\n\nDetailed notes: [`Docs/MILESTONE-1.8.1.md`](Docs/MILESTONE-1.8.1.md) and [`Docs/FRONT-END-NAVIGATION.md`](Docs/FRONT-END-NAVIGATION.md).\n\n'''
s = s.replace(needle, section + needle, 1)
p.write_text(s)

p = Path('Docs/ROADMAP.md')
s = p.read_text()
needle = '''### Milestone 1.8 — Native Front-End & Title Screen\n\nThe Apple products now boot through a shared native title shell instead of directly into gameplay. New Game, Controls, persistent presentation Preferences, Credits, macOS Quit, and Return-to-Title pause flow are live; the recovered 48-frame ship bank supplies the title emblem. `ZONE_BOOT_DIRECT=1` retains direct engineering boot, and ZoneCore/high-refresh/audio behavior is deliberately unchanged.\n\n'''
if needle not in s:
    raise SystemExit('ERROR: expected Milestone 1.8 roadmap section not found')
insert = needle + '''### Milestone 1.8.1 — Front-End Polish & Navigation\n\nThe native shell now has explicit controller/keyboard selection semantics instead of depending on pointer/touch or incidental platform focus behavior. D-pad/left stick navigates, primary activates, secondary/Menu backs out, Preferences can be changed from a controller, and iPad Pause can be fully operated from a controller. Hardware-key arrows/Return/Escape share the same selection model. Safe-area layout, screen transitions, title selection treatment, and pause styling are polished while ZoneCore and all accepted gameplay/runtime paths remain frozen.\n\n'''
s = s.replace(needle, insert, 1)
s = s.replace('## Phase 5 — Native product/UI layer — ~48%', '## Phase 5 — Native product/UI layer — ~53%', 1)
completed_needle = '- direct developer boot retained through `ZONE_BOOT_DIRECT=1`.\n'
if completed_needle in s:
    s = s.replace(completed_needle, completed_needle + '- explicit controller and hardware-key front-end navigation with visible selection state;\n- controller-operable iPad pause and Preferences screens;\n- safe-area-aware iPad title/subpage layout and unified front-end transitions/pause styling.\n', 1)
p.write_text(s)
PY

chmod +x APPLY-MILESTONE-1.8.1.command Tools/verify-milestone-1.8.1.command
./Tools/verify-milestone-1.8.1.command

echo
echo "Milestone 1.8.1 candidate applied and verified."
echo "macOS build: ./Tools/build-macos.command"
echo "macOS run:   ./Tools/run-macos-refresh.command native high"
echo "iPad: open TheZoneRemastered.xcodeproj, select The Zone iPadOS + tethered iPad Pro, then Run (Cmd-R)."
echo "Do not commit until both hardware play tests feel right."
