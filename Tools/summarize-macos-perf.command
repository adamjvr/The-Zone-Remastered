#!/bin/sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ "$#" -gt 0 ]; then
  LOG="$1"
else
  LOG="$(ls -1t build/perf-logs/zone-perf-*.log 2>/dev/null | head -n 1 || true)"
fi

if [ -z "${LOG:-}" ] || [ ! -f "$LOG" ]; then
  echo "ERROR: no perf log found. Pass a log path or run ./Tools/run-macos-perf.command first."
  exit 1
fi

echo "ZonePerf summary: $LOG"

/usr/bin/awk '
function value(name,    i,a) {
  for (i=1; i<=NF; ++i) {
    split($i,a,"=")
    if (a[1] == name) return a[2]
  }
  return ""
}
function msfield(s) { sub(/ms$/, "", s); return s + 0 }
/\[ZonePerf\]\[renderer\] sprite-preload/ { preload=$0 }
/\[ZonePerf\]\[renderer\] texture-miss/ { textureMiss++ }
/\[ZonePerf\]\[audio\] voice-steal/ { voiceSteal++ }
/\[ZonePerf\]\[renderer\] frame-gap/ {
  frameGap++
  v=msfield($NF)
  if (v > maxGap) { maxGap=v; maxGapFrame=value("frame") }
}
/\[ZonePerf\]\[audio\] slow-trigger/ {
  slowAudio++
  v=value("total")+0
  if (v > maxSlowAudio) {
    maxSlowAudio=v
    maxSlowSid=value("sid")
    maxSlowEvent=value("event")
    maxSlowVoice=value("voice")
  }
}
/\[ZonePerf\]\[host-detail/ {
  host++
  total=value("total")+0
  input=value("input")+0
  core=value("core")+0
  drain=value("drain")+0
  audio=value("audio")+0
  hud=value("hud")+0
  dom=value("dominant")
  domCount[dom]++

  if (total > 16.667) over16++
  if (total > 20.0) over20++
  if (total > 50.0) over50++

  if (total > maxTotal) { maxTotal=total; maxTotalFrame=value("frame"); maxTotalDom=dom }
  if (input > maxInput) maxInput=input
  if (core > maxCore) maxCore=core
  if (drain > maxDrain) maxDrain=drain
  if (audio > maxAudio) maxAudio=audio
  if (hud > maxHud) maxHud=hud
}
END {
  if (preload != "") print "  " preload
  printf "  frame gaps: %d", frameGap+0
  if (frameGap) printf " (max %.3f ms at frame %s)", maxGap, maxGapFrame
  print ""

  printf "  host-detail slow steps: %d", host+0
  if (host) printf " | >16.7 ms: %d | >20 ms: %d | >50 ms: %d\n", over16+0, over20+0, over50+0
  else print ""

  if (host) {
    printf "  worst host step: %.3f ms at frame %s (dominant=%s)\n", maxTotal, maxTotalFrame, maxTotalDom
    printf "  stage maxima: input %.3f | core %.3f | drain %.3f | audio %.3f | hud %.3f ms\n", maxInput, maxCore, maxDrain, maxAudio, maxHud
    printf "  dominant-stage counts: input %d | core %d | drain %d | audio %d | hud %d\n", domCount["input"]+0, domCount["core"]+0, domCount["drain"]+0, domCount["audio"]+0, domCount["hud"]+0
  }

  printf "  slow audio triggers (>2 ms): %d", slowAudio+0
  if (slowAudio) printf " (max %.3f ms sid=%s event=%s voice=%s)", maxSlowAudio, maxSlowSid, maxSlowEvent, maxSlowVoice
  print ""
  printf "  texture misses: %d | voice steals: %d\n", textureMiss+0, voiceSteal+0
}
' "$LOG"
