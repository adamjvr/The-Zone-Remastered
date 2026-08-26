#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

TARGET = Path("Shared/ZoneContentView.swift")
MARKER_111 = "Milestone 1.11.1 front-end frame-pacing hotfix"
MARKER_112 = "Milestone 1.11.2 predecoded interpolated title ship"


def splice_between(source: str, start_marker: str, end_marker: str, replacement: str) -> str:
    start = source.find(start_marker)
    if start < 0:
        raise RuntimeError(f"missing start marker: {start_marker!r}")
    end = source.find(end_marker, start)
    if end < 0:
        raise RuntimeError(f"missing end marker: {end_marker!r}")
    if source.find(start_marker, start + len(start_marker)) >= 0:
        raise RuntimeError(f"start marker is not unique: {start_marker!r}")
    return source[:start] + replacement + source[end:]


def patch_source(source: str) -> str:
    if MARKER_112 in source:
        return source
    if MARKER_111 not in source:
        raise RuntimeError("Hotfix 1.11.1 must be applied before 1.11.2")

    import_anchor = "import GameController\nimport SwiftUI\n"
    if source.count(import_anchor) != 1:
        raise RuntimeError("unexpected Shared/ZoneContentView.swift import block")
    source = source.replace(
        import_anchor,
        "import GameController\nimport ImageIO\nimport SwiftUI\n",
        1,
    )

    ship = r'''private struct ZoneRotatingShip: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      // Milestone 1.11.2 predecoded interpolated title ship:
      // 1.11.1 removed the gross 5-Hz jump, but its lazy cache could still
      // decode one new PNG on the animation path every 200 ms during the first
      // revolution. It also dissolved between 7.5-degree poses without moving
      // their silhouettes through the interval. 1.11.2 predecodes all 48
      // recovered views as CGImages in one batch and geometrically aligns the
      // two neighboring poses at the continuous in-between heading.
      let time = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
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

      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [.cyan.opacity(0.20), .purple.opacity(0.075), .clear],
              center: .center,
              startRadius: 2,
              endRadius: 120
            )
          )

        Circle()
          .stroke(.cyan.opacity(0.18), lineWidth: 1)
          .padding(20)

        Circle()
          .trim(from: 0.08, to: 0.72)
          .stroke(.purple.opacity(0.42), style: StrokeStyle(lineWidth: 2, dash: [4, 8]))
          .padding(8)
          .rotationEffect(.degrees(primaryRingDegrees))

        Circle()
          .trim(from: 0.58, to: 0.93)
          .stroke(.cyan.opacity(0.32), style: StrokeStyle(lineWidth: 1, dash: [2, 12]))
          .padding(1)
          .rotationEffect(.degrees(secondaryRingDegrees))

        ZStack {
          ZoneBundledSpriteFrame(frame: baseFrame)
            .rotationEffect(.degrees(interpolatedStepDegrees))
            .opacity(1.0 - spriteBlend)

          if !reduceMotion && spriteBlend > 0.0 {
            ZoneBundledSpriteFrame(frame: nextFrame)
              .rotationEffect(.degrees(interpolatedStepDegrees - frameStepDegrees))
              .opacity(spriteBlend)
          }
        }
        .compositingGroup()
        .padding(38)
        .shadow(color: .cyan.opacity(0.78), radius: 10)
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

/// Fully decoded recovered title-ship frames.  ImageIO's immediate-cache flag
/// makes decompression a one-time cost when the store is first touched, rather
/// than a recurring cost on display-driven SwiftUI animation updates.
private enum ZoneTitleShipFrameStore {
  private static let frames: [CGImage?] = {
    let imageOptions = [kCGImageSourceShouldCacheImmediately: true] as CFDictionary

    return (0..<48).map { frame -> CGImage? in
      let resource = String(format: "Spri_%05d", 1000 + frame)
      guard let url = Bundle.main.url(
        forResource: resource,
        withExtension: "png",
        subdirectory: "Sprites"
      ), let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
        return nil
      }
      return CGImageSourceCreateImageAtIndex(source, 0, imageOptions)
    }
  }()

  static func frame(_ index: Int) -> CGImage? {
    guard !frames.isEmpty else { return nil }
    let normalized = ((index % frames.count) + frames.count) % frames.count
    return frames[normalized]
  }
}

private struct ZoneBundledSpriteFrame: View {
  let frame: Int

  @ViewBuilder var body: some View {
    if let image = ZoneTitleShipFrameStore.frame(frame) {
      Image(decorative: image, scale: 1.0, orientation: .up)
        .resizable()
        .interpolation(.none)
        .scaledToFit()
    } else {
      Color.clear
    }
  }
}
'''

    source = splice_between(
        source,
        "private struct ZoneRotatingShip: View {",
        "\nprivate struct ZoneTitleBackdrop: View {",
        ship,
    )

    # Defensive checks: 1.11.2 should completely replace the 1.11.1 lazy cache.
    if "private enum ZoneBundledSpriteCache" in source:
        raise RuntimeError("legacy 1.11.1 lazy sprite cache survived replacement")
    if "ZoneBundledSpriteImage(resource:" in source:
        raise RuntimeError("legacy resource-name animated image path survived replacement")

    return source


def self_test() -> None:
    fixture = '''import Foundation\nimport GameController\nimport SwiftUI\n\n// Milestone 1.11.1 front-end frame-pacing hotfix\nprivate struct ZoneRotatingShip: View {\nold\n}\nprivate enum ZoneBundledSpriteCache {\nold\n}\nprivate struct ZoneBundledSpriteImage: View {\nold\n}\n\nprivate struct ZoneTitleBackdrop: View {\nold\n}\n'''
    patched = patch_source(fixture)
    assert MARKER_112 in patched
    assert "import ImageIO" in patched
    assert "kCGImageSourceShouldCacheImmediately" in patched
    assert "ZoneTitleShipFrameStore" in patched
    assert "interpolatedStepDegrees" in patched
    assert "ZoneBundledSpriteCache" not in patched
    assert "ZoneBundledSpriteImage(resource:" not in patched
    assert patch_source(patched) == patched
    print("1.11.2 patcher self-test: PASS")


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        self_test()
        return 0

    if not TARGET.is_file():
        print(f"ERROR: missing {TARGET}; run from the repository root", file=sys.stderr)
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
