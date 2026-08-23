#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/zone-perf-summary-$$.log"
OUT="${TMP}.out"
trap 'rm -f "$TMP" "$OUT"' EXIT HUP INT TERM

cat > "$TMP" <<'LOG'
[ZonePerf][renderer] sprite-preload urls=651 loaded=651 failed=0
[ZonePerf][host-detail] frame=10 total=75.000 input=0.100 core=0.500 drain=0.010 audio=74.000 audioMax=74.000 audioType=2 hud=0.020 hudPub=0 events=1 dominantMS=74.000 wave=1 bases=0 enemies=0 world=3 shots=0 hostile=0 tick=10 dominant=audio
[ZonePerf][audio] slow-trigger sid=130 event=2 voice=0 total=73.500 reset=0.010 play=73.490 started=1
[ZonePerf][renderer] frame-gap frame=11 83.000ms
LOG

"$ROOT/Tools/summarize-macos-perf.command" "$TMP" > "$OUT"
grep -q 'host-detail slow steps: 1 | >16.7 ms: 1 | >20 ms: 1 | >50 ms: 1' "$OUT"
grep -q 'worst host step: 75.000 ms at frame 10 (dominant=audio)' "$OUT"
grep -q 'dominant-stage counts: input 0 | core 0 | drain 0 | audio 1 | hud 0' "$OUT"
grep -q 'slow audio triggers (>2 ms): 1 (max 73.500 ms sid=130 event=2 voice=0)' "$OUT"
grep -q 'frame gaps: 1 (max 83.000 ms at frame 11)' "$OUT"
echo 'Perf summary parser: PASS'
