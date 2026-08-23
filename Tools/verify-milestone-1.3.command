#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
BASE="f7894f0b8a28a2016fe6f593585fd4ecd335ad42"

echo "============================================================"
echo "The Zone Remastered — Milestone 1.3 verification"
echo "============================================================"

OUT="$(mktemp -t thezone-m13.XXXXXX)"
trap 'rm -f "$OUT"' EXIT
./Tools/test-zonecore.sh | tee "$OUT"

grep -Fq "Wave-2 nonlethal Mother hit -> other-base Bee request: PASS" "$OUT"
grep -Fq "Bee recovered 60-tick hit-state coast/resume: PASS" "$OUT"
grep -Fq "Seeker collision 30-of-60 tick hit-state gate: PASS" "$OUT"
grep -Fq "Seeker 200-unit near/far speed switch: PASS" "$OUT"
grep -Fq "Recovered Rotor orbit/attack/return + wake/link/fire semantics: PASS" "$OUT"

grep -Fq 'tz_enemy_hit_state_duration' ZoneCore/Recovered/src/ai.c
grep -Fq 'tz_seeker_player_collision_hit_backdate' ZoneCore/Recovered/src/ai.c
grep -Fq 'enemy_hit_state_active' ZoneCore/src/zone_core.c
grep -Fq 'zone_game_debug_world_hit_state' ZoneCore/include/zone_core.h
grep -Fq 'PPC 0x1A0B4..0x1A0C8' ZoneCore/src/zone_core.c

# 1.3 is gameplay-only. The accepted 1.1 renderer/audio repair and 1.2 host
# attribution path must remain byte-for-byte unchanged from the committed base.
if ! git diff --quiet "$BASE" -- \
  Shared/ZoneRenderer.swift Shared/ZoneAudioEngine.swift Shared/ZoneGameHost.swift \
  Tools/run-macos-perf.command; then
  echo "ERROR: Milestone 1.3 unexpectedly changed accepted realtime/diagnostic files."
  git diff "$BASE" -- Shared/ZoneRenderer.swift Shared/ZoneAudioEngine.swift Shared/ZoneGameHost.swift Tools/run-macos-perf.command
  exit 1
fi

grep -Fq '**Current phase: Milestone 1.3.**' Docs/ROADMAP.md
grep -Fq 'Milestone 1.4 — High-refresh engine/timebase foundation' Docs/ROADMAP.md
grep -Fq 'No recovered Bee return state' Docs/RE-bee-seeker.md
grep -Fq '# The Zone Remastered — Engineering Milestone 1.3' README.md

if [[ -x Tools/verify-native-targets.command ]]; then
  ./Tools/verify-native-targets.command
fi

echo
echo "Milestone 1.3 Bee/Seeker integration checks: PASS"
