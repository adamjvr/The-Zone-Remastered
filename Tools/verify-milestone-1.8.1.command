#!/bin/zsh
set -euo pipefail

cd "${0:A:h}/.."

BASE_SHA="7064192e475b39fd85cc45167637ad3b43d7bbcd"

if [[ ! -d .git ]]; then
  echo "ERROR: run from the The-Zone-Remastered repository root."
  exit 1
fi

if [[ "$(git rev-parse HEAD)" != "$BASE_SHA" ]]; then
  echo "ERROR: Milestone 1.8.1 requires committed Milestone 1.8 at $BASE_SHA"
  echo "Current HEAD: $(git rev-parse HEAD)"
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
    echo "ERROR: protected gameplay/runtime path changed: $path"
    exit 1
  fi
done

shasum -a 256 -c FILES.sha256

required_markers=(
  'ZoneFrontEndInputMonitor'
  'GCInputDirectionPad'
  'GCInputLeftThumbstick'
  'primeEdges()'
  'ZoneMenuActionButton'
  'onKeyPress(.upArrow)'
  'onKeyPress(.escape)'
  'Milestone 1.8.1 — Front-End Polish & Navigation'
)

for marker in $required_markers; do
  if ! grep -Fq "$marker" Shared/ZoneContentView.swift Docs/MILESTONE-1.8.1.md 2>/dev/null; then
    echo "ERROR: missing 1.8.1 marker: $marker"
    exit 1
  fi
done

if ! grep -q 'Engineering Milestone 1.8.1' README.md; then
  echo "ERROR: README was not promoted to Milestone 1.8.1"
  exit 1
fi
if ! grep -q 'Milestone 1.8.1 — Front-End Polish & Navigation' Docs/ROADMAP.md; then
  echo "ERROR: roadmap was not updated for Milestone 1.8.1"
  exit 1
fi

xcrun swiftc -frontend -parse Shared/ZoneContentView.swift

./Tools/test-zonecore.sh
./Tools/test-zone-timebase.command
./Tools/verify-native-targets.command

echo
echo "Milestone 1.8.1 verification passed."
echo "ZoneCore and accepted high-refresh/audio/runtime paths are unchanged."
echo "Front-end controller + keyboard navigation and iPad pause navigation are present."
