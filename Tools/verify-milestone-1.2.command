#!/bin/zsh
set -euo pipefail
cd "${0:A:h}/.."
BASE="e3bdbbcf5d04672da2de4ce738669394bdb5b66c"

fail() { echo "ERROR: $*" >&2; exit 1; }

# The attribution phase is not allowed to change simulation or presentation.
git diff --quiet "$BASE" -- ZoneCore || fail "Milestone 1.2 must not modify ZoneCore."
git diff --quiet "$BASE" -- Shared/ZoneRenderer.swift || fail "Milestone 1.2 must not modify ZoneRenderer.swift."

grep -q 'private let diagnosticsEnabled' Shared/ZoneGameHost.swift || fail "host diagnostics gate missing"
grep -q 'if !diagnosticsEnabled' Shared/ZoneGameHost.swift || fail "accepted non-diagnostic fast path missing"
grep -q '\[ZonePerf\]\[host-detail\]' Shared/ZoneGameHost.swift || fail "host-detail record missing"
grep -q 'dominantMS' Shared/ZoneGameHost.swift || fail "host dominant-stage attribution missing"
grep -q 'zone_game_debug_behavior_tick' Shared/ZoneGameHost.swift || fail "behavior-tick correlation missing"
grep -q '\[ZonePerf\]\[audio\] slow-trigger' Shared/ZoneAudioEngine.swift || fail "audio trigger split missing"
grep -q 'resetMS' Shared/ZoneAudioEngine.swift || fail "audio rewind timing missing"
grep -q 'playMS' Shared/ZoneAudioEngine.swift || fail "audio play timing missing"
grep -q 'summarize-macos-perf.command' Tools/run-macos-perf.command || fail "perf runner does not auto-summarize"
grep -q 'dominant-stage counts' Tools/summarize-macos-perf.command || fail "perf summary dominant histogram missing"
grep -q 'Milestone 1.2' Docs/MILESTONE-1.2.md || fail "Milestone 1.2 docs missing"
grep -q 'Host Stall Attribution' Docs/RE-host-stall-attribution.md || fail "RE attribution docs missing"
grep -q 'Engineering Milestone 1.2' README.md || fail "README current milestone marker missing"
grep -q 'Current phase: Milestone 1.2' Docs/ROADMAP.md || fail "roadmap current milestone marker missing"

/bin/sh -n Tools/summarize-macos-perf.command
/bin/sh -n Tools/test-perf-summary.command
zsh -n Tools/run-macos-perf.command
zsh -n Tools/verify-milestone-1.2.command

./Tools/test-perf-summary.command
./Tools/test-zonecore.sh

swiftc -parse Shared/ZoneGameHost.swift Shared/ZoneAudioEngine.swift Shared/ZoneRenderer.swift

if [[ -x Tools/verify-native-targets.command ]]; then
  ./Tools/verify-native-targets.command
fi

echo "Milestone 1.2 host stall attribution checks: PASS"
