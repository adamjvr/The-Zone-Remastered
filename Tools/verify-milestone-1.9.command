#!/bin/zsh
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
cd "${0:A:h}/.."

if [[ ! -d .git ]]; then
  echo "ERROR: run from the The-Zone-Remastered repository root."
  exit 1
fi

expected_base="b998e13e0c328df935fb6d142f1179c0a036d9a2"
actual_base="$(/usr/bin/git rev-parse HEAD)"
if [[ "$actual_base" != "$expected_base" ]]; then
  echo "ERROR: Milestone 1.9 requires committed Milestone 1.8.1 base $expected_base."
  echo "Actual HEAD: $actual_base"
  exit 1
fi

head_hash() {
  /usr/bin/git show "HEAD:$1" 2>/dev/null | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'
}
check_head_hash() {
  local file_path="$1" expected="$2" actual
  actual="$(head_hash "$file_path" || true)"
  if [[ "$actual" != "$expected" ]]; then
    echo "ERROR: committed 1.8.1 base mismatch: $file_path"
    echo "Expected $expected"
    echo "Actual   ${actual:-missing}"
    exit 1
  fi
}

check_head_hash ZoneCore/src/zone_core.c bf0f59e07e222cfb85889a4283e3b7ee78bc49d172049b1cc7d2ca02486d1128
check_head_hash ZoneCore/include/zone_core.h dddbfa7e14d8eb24291a256390c4aaac377ce2c59a5c5e99422b229ec2f0fbf3
check_head_hash ZoneCore/tests/test_zone_core.c 8a533c6eee728d8945e01ea217cc6b1e2d771bb1428e4bdc40aff42f56994e7a
check_head_hash Shared/ZoneContentView.swift a06abc8507d220b4a06025fa6dab468f4e742c10a0679c0c937acd8b8abab18b

if ! git show HEAD:README.md | grep -q 'Engineering Milestone 1.8.1'; then
  echo "ERROR: committed README is not accepted Milestone 1.8.1."
  exit 1
fi

/usr/bin/shasum -a 256 -c FILES.sha256

# Product/runtime shell must stay exactly at the accepted 1.8.1 checkpoint.
protected=(
  Shared
  macOS
  iPadOS
  project.yml
  TheZoneRemastered.xcodeproj
)
for protected_path in $protected; do
  if ! git diff --quiet HEAD -- "$protected_path"; then
    echo "ERROR: 1.9 unexpectedly changes protected product/runtime path: $protected_path"
    exit 1
  fi
done

required_markers=(
  'spatial_active; /* PPC +128'
  'projectile_outside_classic_live_region'
  'Classic SHOT positions remain in screen space'
  'Recovered +128 spatial retirement replaces'
  'test_recovered_projectile_spatial_retirement'
  'test_native_projectile_retirement_on_classic_boundary'
  'test_hostile_spatial_retirement_releases_source_cap'
)
for marker in $required_markers; do
  if ! grep -Fq "$marker" ZoneCore/src/zone_core.c ZoneCore/tests/test_zone_core.c 2>/dev/null; then
    echo "ERROR: missing Milestone 1.9 marker: $marker"
    exit 1
  fi
done

if grep -Eq 'p->life|life = 90|life = 120|struct Projectile[^}]*life' ZoneCore/src/zone_core.c; then
  echo "ERROR: provisional projectile lifetime code remains."
  exit 1
fi

if ! grep -q 'Engineering Milestone 1.9' README.md; then
  echo "ERROR: README was not promoted to Milestone 1.9."
  exit 1
fi
if ! grep -q 'Milestone 1.9 — Recovered projectile spatial retirement' Docs/ROADMAP.md; then
  echo "ERROR: roadmap was not updated for Milestone 1.9."
  exit 1
fi

./Tools/test-zonecore.sh
./Tools/test-zone-timebase.command
./Tools/benchmark-zonecore.command 1200
./Tools/verify-native-targets.command

git diff --check

echo
echo "Milestone 1.9 verification passed."
echo "Provisional 90/120 projectile lifetimes are gone."
echo "SHOT/FIRE retire through recovered +128 live-region semantics."
echo "720-Hz motion and 60-Hz Classic spatial/collision boundaries remain separated."
