#!/bin/zsh
set -euo pipefail
BASE="6df5e5da9985eaa379a385c5e49af49c8f9e912c"

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi
if [[ "$(git rev-parse HEAD)" != "$BASE" ]]; then
  echo "ERROR: this candidate is deliberately based on exact Milestone 1.0."
  echo "Expected HEAD: $BASE"
  echo "Actual HEAD:   $(git rev-parse HEAD)"
  exit 1
fi

if [[ ! -f FILES.sha256 ]]; then
  echo "ERROR: FILES.sha256 missing; re-extract the milestone ZIP into the repo root."
  exit 1
fi
shasum -a 256 -c FILES.sha256

# If either rejected 1.1 experiment is still in the working tree, preserve a
# patch before restoring only the timing/core files that those experiments
# contaminated. Renderer/audio are intentionally replaced by this package.
mkdir -p build/milestone-1.1-backups
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="build/milestone-1.1-backups/preapply-${STAMP}.patch"
git diff "$BASE" -- \
  README.md Docs/ROADMAP.md Shared/ZoneGameHost.swift \
  ZoneCore/include/zone_core.h ZoneCore/src/zone_core.c ZoneCore/tests/test_zone_core.c \
  > "$BACKUP" || true
if [[ ! -s "$BACKUP" ]]; then rm -f "$BACKUP"; else echo "Saved previous experimental diff: $BACKUP"; fi

git restore --source="$BASE" --worktree -- \
  README.md Docs/ROADMAP.md Shared/ZoneGameHost.swift \
  ZoneCore/include/zone_core.h ZoneCore/src/zone_core.c ZoneCore/tests/test_zone_core.c

rm -f \
  Docs/RE-timing-audio.md \
  Tools/test-fixed-step-clock.command Tools/test-fixed-step-clock.swift \
  Tools/test-presentation-math.command Tools/test-presentation-math.swift

# Mark the repair gate in the existing roadmap without replacing the rest of it.
python3 - <<'PY'
from pathlib import Path
p=Path('Docs/ROADMAP.md')
s=p.read_text()
old='**Current phase: Milestone 1.0.**'
new='''**Current phase: Milestone 1.1.**\n\nMilestone 1.1 is a narrow real-time hot-path repair on the committed 1.0 gameplay baseline. It keeps ZoneCore and the 60-Hz host stepping contract unchanged while removing first-use PNG/Metal texture construction and per-event WAV/player construction from active gameplay. Opt-in hitch telemetry is included before any further timing-model changes.'''
if old not in s:
    raise SystemExit('ERROR: expected Milestone 1.0 roadmap marker not found after baseline restore')
p.write_text(s.replace(old,new,1))
PY

chmod +x Tools/verify-milestone-1.1.command Tools/run-macos-perf.command Tools/test-zonecore.sh Tools/verify-native-targets.command 2>/dev/null || true

./Tools/verify-milestone-1.1.command

echo
echo "Milestone 1.1 candidate applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "If a hitch remains after normal play: ./Tools/run-macos-perf.command"
echo "Do not commit until the play test is accepted."
