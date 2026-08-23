#!/bin/sh
set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
python3 - "$ROOT/Shared/ZoneGameHost.swift" "$TMP/timebase.swift" <<'PY'
from pathlib import Path
import sys
src=Path(sys.argv[1]).read_text()
a='// ZONE_TIMEBASE_BEGIN\n'
b='// ZONE_TIMEBASE_END'
if a not in src or b not in src:
    raise SystemExit('timebase markers missing')
body=src.split(a,1)[1].split(b,1)[0]
Path(sys.argv[2]).write_text('import Foundation\n\n'+body+r'''

func require(_ ok: @autoclosure () -> Bool, _ message: String) {
  if !ok() { fatalError(message) }
}

func countSteps(refreshHz: Int, seconds: Int = 1) -> Int {
  var tb = ZoneTimebase()
  var total = 0
  for frame in 0...(refreshHz * seconds) {
    let t = Double(frame) / Double(refreshHz)
    total += tb.plan(at: t).classicSteps
  }
  return total
}

require(ZoneTimebase.masterHz == 720, "master rate")
require(ZoneTimebase.masterTicksPerClassicStep == 12, "classic divisor")
for hz in [60, 120, 144, 165, 240] {
  require(countSteps(refreshHz: hz) == 61, "display rate changed 1-second game speed at \(hz) Hz")
  require(countSteps(refreshHz: hz, seconds: 10) == 601, "display rate drifted over 10 seconds at \(hz) Hz")
}

var tb120 = ZoneTimebase()
require(tb120.plan(at: 0).classicSteps == 1, "first presentation")
require(tb120.plan(at: 1.0 / 120.0).classicSteps == 0, "120-Hz half-step")
require(tb120.plan(at: 2.0 / 120.0).classicSteps == 1, "120-Hz full Classic step")

var tb240 = ZoneTimebase()
_ = tb240.plan(at: 0)
require(tb240.plan(at: 1.0 / 240.0).classicSteps == 0, "240 frame 1")
require(tb240.plan(at: 2.0 / 240.0).classicSteps == 0, "240 frame 2")
require(tb240.plan(at: 3.0 / 240.0).classicSteps == 0, "240 frame 3")
require(tb240.plan(at: 4.0 / 240.0).classicSteps == 1, "240 frame 4")



var switched = ZoneTimebase()
var switchedTotal = switched.plan(at: 0).classicSteps
for frame in 1...60 { switchedTotal += switched.plan(at: Double(frame) / 120.0).classicSteps }
for frame in 1...120 { switchedTotal += switched.plan(at: 0.5 + Double(frame) / 240.0).classicSteps }
require(switchedTotal == 61, "120->240 Hz switch changed one-second Classic step count")

var jittered = ZoneTimebase()
var jitteredTotal = jittered.plan(at: 0).classicSteps
for frame in 1...239 {
  let ideal = Double(frame) / 240.0
  let jitter = (frame & 1) == 0 ? 0.00030 : -0.00030
  jitteredTotal += jittered.plan(at: ideal + jitter).classicSteps
}
jitteredTotal += jittered.plan(at: 1.0).classicSteps
require(jitteredTotal == 61, "240-Hz callback jitter changed one-second Classic step count")

var stalled = ZoneTimebase()
_ = stalled.plan(at: 0)
let rebased = stalled.plan(at: 1.0)
require(rebased.rebased && rebased.classicSteps == 1, "long-gap rebase")

print("ZoneTimebase tests passed: fixed, switched, and jittered 60-240 Hz presentation preserve Classic speed")
''')
PY
swiftc "$TMP/timebase.swift" -o "$TMP/timebase-test"
"$TMP/timebase-test"
