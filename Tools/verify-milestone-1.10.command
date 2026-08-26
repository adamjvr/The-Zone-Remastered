#!/bin/bash
set -euo pipefail
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

if [[ ! -d .git ]]; then
  echo "ERROR: run from the The-Zone-Remastered repository root."
  exit 1
fi

head_hash() {
  /usr/bin/git show "HEAD:$1" 2>/dev/null | /usr/bin/shasum -a 256 | /usr/bin/awk '{print $1}'
}

# The verifier works both before commit (HEAD=accepted 1.9) and after commit
# (HEAD contains the accepted 1.10 payload). It never requires a specific SHA.
head_core="$(head_hash ZoneCore/src/zone_core.c || true)"
case "$head_core" in
  4f7ee078d0390b4ed62e4553aa51458fbb84a5d97ade134f3d98f659f39629c1)
    verification_mode="candidate-on-1.9"
    ;;
  f54a06d410b5e33a75644c66f78905fc53f101874f0bb85891582bf487a3e337)
    verification_mode="committed-1.10"
    ;;
  *)
    echo "ERROR: HEAD is neither the accepted 1.9 base nor the 1.10 core."
    echo "HEAD ZoneCore/src/zone_core.c SHA-256: ${head_core:-missing}"
    exit 1
    ;;
esac

/usr/bin/shasum -a 256 -c FILES.sha256

# Apple product/runtime shell is outside this gameplay-core milestone.
protected=(
  Shared
  macOS
  iPadOS
  project.yml
  TheZoneRemastered.xcodeproj
)
for protected_path in "${protected[@]}"; do
  if ! /usr/bin/git diff --quiet HEAD -- "$protected_path"; then
    echo "ERROR: Milestone 1.10 unexpectedly changes protected path: $protected_path"
    exit 1
  fi
done

required_source_markers=(
  'struct ClassicObjectRef'
  'classic_reset_with_player_head'
  'classic_allocate_and_link'
  'classic_rebind_slot'
  'classic_free_slot'
  'classic_world_index_for_slot'
  'ZONE_DEBUG_CLASSIC_EXPLOSION'
  '0xDDD0/0xDF14/0xDFBC'
  'PPC 0x16568 starts at head->+138'
  'PPC 0x19C38..0x19C98 walks +138'
)
for marker in "${required_source_markers[@]}"; do
  if ! /usr/bin/grep -Fq "$marker" ZoneCore/src/zone_core.c ZoneCore/include/zone_core.h; then
    echo "ERROR: missing Milestone 1.10 source marker: $marker"
    exit 1
  fi
done

required_test_markers=(
  'test_recovered_allocator_and_list_order'
  'test_hq_and_enemy_projectile_list_modes'
  'zone_game_debug_explosion_classic_slot(g, 0) == 0'
  'zone_game_debug_world_classic_slot(g, 0) == 79'
  'zone_game_debug_projectile_classic_slot(g, reused) == 1'
)
for marker in "${required_test_markers[@]}"; do
  if ! /usr/bin/grep -Fq "$marker" ZoneCore/tests/test_zone_core.c; then
    echo "ERROR: missing Milestone 1.10 regression marker: $marker"
    exit 1
  fi
done

if ! /usr/bin/grep -q 'Engineering Milestone 1.10' README.md; then
  echo "ERROR: README was not promoted to Milestone 1.10."
  exit 1
fi
if ! /usr/bin/grep -q 'Milestone 1.10 — Shared Object Slots & +138 List Fidelity' Docs/ROADMAP.md; then
  echo "ERROR: roadmap was not updated for Milestone 1.10."
  exit 1
fi
if ! /usr/bin/grep -q 'Milestone 1.11 — recover the original camera/world-to-screen transform' Docs/ROADMAP.md; then
  echo "ERROR: roadmap does not preserve the deferred camera/+128/+129 dependency."
  exit 1
fi

./Tools/test-zonecore.sh
./Tools/test-zone-timebase.command
./Tools/benchmark-zonecore.command 1200
./Tools/verify-native-targets.command

/usr/bin/git diff --check

echo
echo "Milestone 1.10 verification passed ($verification_mode)."
echo "Recovered 80-slot directional reuse and +138 list ordering are live."
echo "Ship/world -> EXPL retains Classic slot/list identity."
echo "Non-projectile +128/+129 remains intentionally deferred to camera/world-to-screen recovery."
