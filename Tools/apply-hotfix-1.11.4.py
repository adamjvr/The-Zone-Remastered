#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

TARGET = Path("Shared/ZoneContentView.swift")
REQ_113 = "Milestone 1.11.3 macOS key-window input isolation"
REQ_112 = "Milestone 1.11.2 predecoded interpolated title ship"
MARKER = "Milestone 1.11.4 cinematic title motion"


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one source anchor, found {count}")
    return source.replace(old, new, 1)


def patch_source(source: str) -> str:
    if MARKER in source:
        return source
    if REQ_112 not in source:
        raise RuntimeError("Hotfix 1.11.2 must be present before 1.11.4")
    if REQ_113 not in source:
        raise RuntimeError("Hotfix 1.11.3r1 must be applied before 1.11.4")

    old = '''      let time = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
      let cycleDuration = 48.0 / 5.0
      let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
      let spritePosition = cycleTime * 5.0
      let basePosition = floor(spritePosition)
      let baseFrame = Int(basePosition) % 48
      let nextFrame = (baseFrame + 1) % 48
      let spriteBlend = reduceMotion ? 0.0 : spritePosition - basePosition
      let frameStepDegrees = 360.0 / 48.0
      let interpolatedStepDegrees = spriteBlend * frameStepDegrees
      let primaryRingDegrees = (time * 37.5).truncatingRemainder(dividingBy: 360.0)
      let secondaryRingDegrees = (time * -18.75).truncatingRemainder(dividingBy: 360.0)
'''

    new = '''      let time = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate

      // Milestone 1.11.4 cinematic title motion:
      // The prior 9.6-second revolution was technically smooth but visually
      // frantic. Default to a deliberate 24-second revolution and let a debug
      // environment override tune the art direction without another rebuild.
      let requestedCycle = ProcessInfo.processInfo.environment["ZONE_TITLE_ROTATION_SECONDS"]
        .flatMap(Double.init) ?? 24.0
      let cycleDuration = min(120.0, max(12.0, requestedCycle))
      let spriteFramesPerSecond = 48.0 / cycleDuration
      let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
      let spritePosition = cycleTime * spriteFramesPerSecond
      let basePosition = floor(spritePosition)
      let baseFrame = Int(basePosition) % 48
      let nextFrame = (baseFrame + 1) % 48
      let spriteBlend = reduceMotion ? 0.0 : spritePosition - basePosition
      let frameStepDegrees = 360.0 / 48.0
      let interpolatedStepDegrees = spriteBlend * frameStepDegrees

      // Decouple the decorative arcs from the ship. Slow counter-motion reads
      // like an instrument display instead of a spinner chasing the sprite.
      let primaryRingDegrees = (time * 7.5).truncatingRemainder(dividingBy: 360.0)   // 48 s/rev
      let secondaryRingDegrees = (time * -4.0).truncatingRemainder(dividingBy: 360.0) // 90 s/rev
'''

    source = replace_once(source, old, new, "title motion constants")
    return source


def self_test() -> None:
    fixture = '''// Milestone 1.11.2 predecoded interpolated title ship\n// Milestone 1.11.3 macOS key-window input isolation\n      let time = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate\n      let cycleDuration = 48.0 / 5.0\n      let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)\n      let spritePosition = cycleTime * 5.0\n      let basePosition = floor(spritePosition)\n      let baseFrame = Int(basePosition) % 48\n      let nextFrame = (baseFrame + 1) % 48\n      let spriteBlend = reduceMotion ? 0.0 : spritePosition - basePosition\n      let frameStepDegrees = 360.0 / 48.0\n      let interpolatedStepDegrees = spriteBlend * frameStepDegrees\n      let primaryRingDegrees = (time * 37.5).truncatingRemainder(dividingBy: 360.0)\n      let secondaryRingDegrees = (time * -18.75).truncatingRemainder(dividingBy: 360.0)\n'''
    patched = patch_source(fixture)
    assert MARKER in patched
    assert '?? 24.0' in patched
    assert 'spriteFramesPerSecond = 48.0 / cycleDuration' in patched
    assert 'time * 7.5' in patched
    assert 'time * -4.0' in patched
    assert '48.0 / 5.0' not in patched
    assert 'time * 37.5' not in patched
    assert patch_source(patched) == patched
    print("1.11.4 patcher self-test: PASS")


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        self_test()
        return 0
    if not TARGET.is_file():
        print(f"ERROR: missing {TARGET}; run from repository root", file=sys.stderr)
        return 1
    source = TARGET.read_text(encoding="utf-8")
    try:
        patched = patch_source(source)
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if patched == source:
        print(f"{TARGET}: hotfix already applied")
        return 0
    TARGET.write_text(patched, encoding="utf-8")
    print(f"Patched {TARGET}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
