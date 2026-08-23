#!/bin/zsh
set -euo pipefail
BASE="92f4e1912310162992f067c70edb7133412b48ec"

if [[ ! -d .git ]]; then
  echo "ERROR: run this from the The-Zone-Remastered repository root."
  exit 1
fi
if [[ "$(git rev-parse HEAD)" != "$BASE" ]]; then
  echo "ERROR: 1.4.1 hotfix expects uncommitted Milestone 1.4 overlay on committed 1.3."
  echo "Expected HEAD: $BASE"
  echo "Actual HEAD:   $(git rev-parse HEAD)"
  exit 1
fi

# Require the 1.4 overlay to already be present. The original 1.4 verifier may
# have aborted at ZoneCore tests; that is the state this hotfix repairs.
grep -q 'static let masterHz: UInt64 = 720' Shared/ZoneGameHost.swift || {
  echo "ERROR: Milestone 1.4 overlay is not present in Shared/ZoneGameHost.swift"
  exit 1
}
grep -q 'Current phase: Milestone 1.4' Docs/ROADMAP.md || {
  echo "ERROR: Milestone 1.4 roadmap overlay is not present"
  exit 1
}

# Patch only the recovered hostile-fire cap helper. The PPC/recovered AI notes
# establish that bloo, raid, bee!, and seek all share object+72 < 3.
python3 - <<'PY'
from pathlib import Path
p = Path('ZoneCore/Recovered/src/ai.c')
s = p.read_text()
old = '''int16_t tz_enemy_fire_active_cap(uint32_t type) {
    switch (type) {
        case TZ_TYPE_BLOO:
        case TZ_TYPE_BEE:
        case TZ_TYPE_SEEK:
        case TZ_TYPE_ROTO:
            return 3;
        default:
            return 0;
    }
}
'''
new = '''int16_t tz_enemy_fire_active_cap(uint32_t type) {
    switch (type) {
        case TZ_TYPE_BLOO:
        case TZ_TYPE_BEE:
        case TZ_TYPE_RAID:
        case TZ_TYPE_SEEK:
        case TZ_TYPE_ROTO:
            return 3;
        default:
            return 0;
    }
}
'''
if old in s:
    p.write_text(s.replace(old, new, 1))
elif new in s:
    print('Raider active-fire cap hotfix already present.')
else:
    raise SystemExit('ERROR: recovered fire-cap helper does not match expected 1.3 source; refusing broad edit')
PY

chmod +x Tools/verify-milestone-1.4.command Tools/test-zonecore.sh Tools/test-zone-timebase.command Tools/benchmark-zonecore.command Tools/verify-native-targets.command 2>/dev/null || true
./Tools/verify-milestone-1.4.command

echo
echo "Milestone 1.4.1 Raider fire-cap hotfix applied and verified."
echo "Build: ./Tools/build-macos.command"
echo "Native refresh test: ./Tools/run-macos-refresh.command native"
echo "Do not commit until the native-refresh play test is accepted."
