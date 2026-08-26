#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

TARGET = Path("Shared/ZoneContentView.swift")
BASE_SHA256 = "a06abc8507d220b4a06025fa6dab468f4e742c10a0679c0c937acd8b8abab18b"
PATCH_MARKER = "Milestone 1.11.1 front-end frame-pacing hotfix"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


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
    if PATCH_MARKER in source:
        return source

    monitor = r'''/// Event-driven front-end controller input. Gameplay keeps using
/// ZoneControllerManager and its recovered semantic input path. The previous
/// menu implementation polled GameController from a 60-Hz main-run-loop Timer;
/// that independent clock competed with SwiftUI's animation timeline and could
/// visibly disturb title-screen frame pacing.  Milestone 1.11.1 binds to the
/// active controller's physical input profile instead, so an idle menu creates
/// no periodic controller work on the UI thread.
private final class ZoneFrontEndInputMonitor: ObservableObject {
  @Published private(set) var hasController = !GCController.controllers().isEmpty

  private var boundProfile: GCPhysicalInputProfile?
  private var observers: [NSObjectProtocol] = []
  private var handler: ((ZoneFrontEndCommand) -> Void)?

  private var lastUp = false
  private var lastDown = false
  private var lastLeft = false
  private var lastRight = false
  private var lastAccept = false
  private var lastBack = false

  init() {
    GCController.startWirelessControllerDiscovery(completionHandler: nil)
    let nc = NotificationCenter.default
    observers.append(
      nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
        self?.controllerTopologyChanged()
      })
    observers.append(
      nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
        self?.controllerTopologyChanged()
      })
  }

  deinit {
    stop()
    observers.forEach { NotificationCenter.default.removeObserver($0) }
  }

  func start(_ handler: @escaping (ZoneFrontEndCommand) -> Void) {
    stop()
    self.handler = handler
    refreshControllerState()
    bindActiveController()
  }

  func stop() {
    boundProfile?.valueDidChangeHandler = nil
    boundProfile = nil
    handler = nil
  }

  private func controllerTopologyChanged() {
    refreshControllerState()
    if handler != nil { bindActiveController() }
  }

  private func refreshControllerState() {
    hasController = !GCController.controllers().isEmpty
  }

  private func activeController() -> GCController? {
    GCController.current ?? GCController.controllers().first
  }

  private func bindActiveController() {
    boundProfile?.valueDidChangeHandler = nil
    boundProfile = nil

    guard handler != nil, let controller = activeController() else {
      primeEdges()
      return
    }

    let profile = controller.physicalInputProfile
    boundProfile = profile
    primeEdges()

    profile.valueDidChangeHandler = { [weak self] _, _ in
      // GameController may deliver profile callbacks away from the main queue.
      // All menu state and edge bookkeeping remains serialized on main.
      DispatchQueue.main.async {
        self?.sample()
      }
    }
  }

  private func currentState() -> (
    up: Bool, down: Bool, left: Bool, right: Bool, accept: Bool, back: Bool
  ) {
    guard let controller = activeController() else {
      return (false, false, false, false, false, false)
    }

    let profile = controller.physicalInputProfile
    let dpad = profile.dpads[GCInputDirectionPad]
    let stick = profile.dpads[GCInputLeftThumbstick]
    let x = abs(stick?.xAxis.value ?? 0) > 0.55 ? (stick?.xAxis.value ?? 0) : (dpad?.xAxis.value ?? 0)
    let y = abs(stick?.yAxis.value ?? 0) > 0.55 ? (stick?.yAxis.value ?? 0) : (dpad?.yAxis.value ?? 0)

    var up = y > 0.55 || dpad?.up.isPressed == true
    var down = y < -0.55 || dpad?.down.isPressed == true
    var left = x < -0.55 || dpad?.left.isPressed == true
    var right = x > 0.55 || dpad?.right.isPressed == true
    var accept = profile.buttons[GCInputButtonA]?.isPressed == true
    var back =
      profile.buttons[GCInputButtonB]?.isPressed == true
      || profile.buttons[GCInputButtonMenu]?.isPressed == true

    if profile.buttons[GCInputButtonA] == nil, let micro = controller.microGamepad {
      up = up || micro.dpad.up.isPressed
      down = down || micro.dpad.down.isPressed
      left = left || micro.dpad.left.isPressed
      right = right || micro.dpad.right.isPressed
      accept = accept || micro.buttonA.isPressed
      back = back || micro.buttonX.isPressed
    }

    return (up, down, left, right, accept, back)
  }

  /// Prime from the currently-held controller state so entering Pause with the
  /// Menu button held cannot immediately trigger the menu's Back action.
  private func primeEdges() {
    let state = currentState()
    lastUp = state.up
    lastDown = state.down
    lastLeft = state.left
    lastRight = state.right
    lastAccept = state.accept
    lastBack = state.back
  }

  private func sample() {
    let state = currentState()

    if state.up && !lastUp { handler?(.up) }
    if state.down && !lastDown { handler?(.down) }
    if state.left && !lastLeft { handler?(.left) }
    if state.right && !lastRight { handler?(.right) }
    if state.accept && !lastAccept { handler?(.accept) }
    if state.back && !lastBack { handler?(.back) }

    lastUp = state.up
    lastDown = state.down
    lastLeft = state.left
    lastRight = state.right
    lastAccept = state.accept
    lastBack = state.back
  }
}
'''

    source = splice_between(
        source,
        "/// Lightweight menu-only controller polling.",
        "\nprivate final class ZoneAppSession",
        monitor,
    )

    ship = r'''private struct ZoneRotatingShip: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      // Milestone 1.11.1 front-end frame-pacing hotfix:
      // keep the original slow 5-frame/sec 48-view ship revolution, but blend
      // adjacent recovered sprite views at the display-driven animation cadence.
      // Decorative rings use continuous time instead of the integer sprite
      // frame, eliminating the old 200-ms rotational jumps.
      let time = reduceMotion ? 0.0 : timeline.date.timeIntervalSinceReferenceDate
      let cycleDuration = 48.0 / 5.0
      let cycleTime = time.truncatingRemainder(dividingBy: cycleDuration)
      let spritePosition = cycleTime * 5.0
      let baseFrame = Int(floor(spritePosition)) % 48
      let nextFrame = (baseFrame + 1) % 48
      let spriteBlend = reduceMotion ? 0.0 : spritePosition - floor(spritePosition)
      let resource = String(format: "Spri_%05d", 1000 + baseFrame)
      let nextResource = String(format: "Spri_%05d", 1000 + nextFrame)
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
          ZoneBundledSpriteImage(resource: resource)
            .opacity(1.0 - spriteBlend)
          if !reduceMotion && spriteBlend > 0.0 {
            ZoneBundledSpriteImage(resource: nextResource)
              .opacity(spriteBlend)
          }
        }
        .padding(38)
        .shadow(color: .cyan.opacity(0.78), radius: 10)
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

/// Bundle sprite cache shared by title/pause/front-end views.  The old body
/// synchronously reopened PNGs with NSImage(contentsOf:)/UIImage(contentsOfFile:)
/// whenever SwiftUI reevaluated the animated view.  Cache each recovered sprite
/// after its first load so animation invalidation never becomes recurring I/O.
private enum ZoneBundledSpriteCache {
  #if os(macOS)
  private static let images = NSCache<NSString, NSImage>()

  static func image(resource: String) -> NSImage? {
    let key = resource as NSString
    if let cached = images.object(forKey: key) { return cached }
    guard let url = Bundle.main.url(
      forResource: resource,
      withExtension: "png",
      subdirectory: "Sprites"
    ), let image = NSImage(contentsOf: url) else {
      return nil
    }
    images.setObject(image, forKey: key)
    return image
  }
  #else
  private static let images = NSCache<NSString, UIImage>()

  static func image(resource: String) -> UIImage? {
    let key = resource as NSString
    if let cached = images.object(forKey: key) { return cached }
    guard let url = Bundle.main.url(
      forResource: resource,
      withExtension: "png",
      subdirectory: "Sprites"
    ), let image = UIImage(contentsOfFile: url.path) else {
      return nil
    }
    images.setObject(image, forKey: key)
    return image
  }
  #endif
}

private struct ZoneBundledSpriteImage: View {
  let resource: String

  @ViewBuilder var body: some View {
    #if os(macOS)
    if let image = ZoneBundledSpriteCache.image(resource: resource) {
      Image(nsImage: image)
        .resizable()
        .interpolation(.none)
        .scaledToFit()
    } else {
      Color.clear
    }
    #else
    if let image = ZoneBundledSpriteCache.image(resource: resource) {
      Image(uiImage: image)
        .resizable()
        .interpolation(.none)
        .scaledToFit()
    } else {
      Color.clear
    }
    #endif
  }
}
'''

    source = splice_between(
        source,
        "private struct ZoneRotatingShip: View {",
        "\nprivate struct ZoneTitleBackdrop: View {",
        ship,
    )

    old_starfield = "TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion))"
    if source.count(old_starfield) != 1:
        raise RuntimeError(
            f"expected exactly one legacy starfield timeline, found {source.count(old_starfield)}"
        )
    source = source.replace(
        old_starfield,
        "TimelineView(.animation(paused: reduceMotion))",
        1,
    )

    return source


def self_test() -> None:
    fixture = '''HEADER\n/// Lightweight menu-only controller polling.\nold\nprivate final class ZoneAppSession\nMIDDLE\nprivate struct ZoneRotatingShip: View {\nold\nprivate struct ZoneTitleBackdrop: View {\nprivate struct ZoneTitleStarfield: View {\n  TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in\n  }\n}\n'''
    patched = patch_source(fixture)
    assert PATCH_MARKER in patched
    assert "Timer(timeInterval: 1.0 / 60.0" not in patched
    assert "valueDidChangeHandler" in patched
    assert "ZoneBundledSpriteCache" in patched
    assert "spriteBlend" in patched
    assert "minimumInterval" not in patched
    assert patch_source(patched) == patched
    print("1.11.1 patcher self-test: PASS")


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "--self-test":
        self_test()
        return 0

    if not TARGET.is_file():
        print(f"ERROR: missing {TARGET}; run from the repository root", file=sys.stderr)
        return 1

    raw = TARGET.read_bytes()
    source = raw.decode("utf-8")
    if PATCH_MARKER in source:
        print(f"{TARGET}: hotfix already applied")
        return 0

    actual = sha256_bytes(raw)
    if actual != BASE_SHA256:
        print("ERROR: Shared/ZoneContentView.swift does not match the accepted 1.10/1.11 front-end base.", file=sys.stderr)
        print(f"Expected SHA-256: {BASE_SHA256}", file=sys.stderr)
        print(f"Actual SHA-256:   {actual}", file=sys.stderr)
        print("Refusing to overwrite unrelated local front-end edits.", file=sys.stderr)
        return 1

    patched = patch_source(source)
    TARGET.write_text(patched, encoding="utf-8")
    print(f"Patched {TARGET}")
    print(f"New SHA-256: {sha256_bytes(TARGET.read_bytes())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
