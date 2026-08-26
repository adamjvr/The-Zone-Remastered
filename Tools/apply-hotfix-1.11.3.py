#!/usr/bin/env python3
from __future__ import annotations

import sys
from pathlib import Path

TARGET = Path("Shared/ZoneContentView.swift")
REQ_112 = "Milestone 1.11.2 predecoded interpolated title ship"
MARKER = "Milestone 1.11.3 macOS key-window input isolation"


def replace_once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one source anchor, found {count}")
    return source.replace(old, new, 1)


def patch_source(source: str) -> str:
    if MARKER in source:
        return source
    # 1.11.2 replaces the 1.11.1 rotating-ship block, so a valid 1.11.2
    # source file no longer necessarily contains the old 1.11.1 marker.
    # Requiring both markers made the original 1.11.3 package reject the
    # exact tree it was intended to patch. The 1.11.2 marker is sufficient.
    if REQ_112 not in source:
        raise RuntimeError("Hotfix 1.11.2 must be applied before 1.11.3")

    # Do not start a Bluetooth/wireless controller scan just because a Mac
    # front-end view exists. Already-connected Mac controllers are still visible
    # through GCController.controllers() and connection notifications. iPad keeps
    # explicit wireless discovery because controller-first use is expected there.
    source = replace_once(
        source,
        "  init() {\n    GCController.startWirelessControllerDiscovery(completionHandler: nil)\n    let nc = NotificationCenter.default\n",
        "  init() {\n"
        "    // Milestone 1.11.3 macOS key-window input isolation: do not run\n"
        "    // wireless controller discovery on a keyboard-driven Mac title\n"
        "    // screen. Existing connected controllers remain discoverable.\n"
        "    #if !os(macOS)\n"
        "    GCController.startWirelessControllerDiscovery(completionHandler: nil)\n"
        "    #endif\n"
        "    let nc = NotificationCenter.default\n",
        "controller discovery gating",
    )

    keyboard_monitor = r'''
#if os(macOS)
/// Native key-window keyboard capture for the animated title screen.
///
/// The title used to become a SwiftUI focus target so `.onKeyPress` could own
/// arrows/Return. That means clicking the game window changes focus state in the
/// same SwiftUI tree that is continuously redrawing the ship and starfield.
/// 1.11.3 removes that coupling on macOS: AppKit delivers key-down events through
/// a local event monitor while the title is visible, with no focusable SwiftUI
/// node and no FocusState mutation on activation.
private final class ZoneMacFrontEndKeyboardMonitor: ObservableObject {
  private var monitor: Any?
  private var handler: ((ZoneFrontEndCommand) -> Void)?

  deinit { stop() }

  func start(_ handler: @escaping (ZoneFrontEndCommand) -> Void) {
    stop()
    self.handler = handler
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
      guard let self, NSApplication.shared.isActive else { return event }

      switch event.keyCode {
      case 126: // up arrow
        self.handler?(.up)
        return nil
      case 125: // down arrow
        self.handler?(.down)
        return nil
      case 123: // left arrow
        self.handler?(.left)
        return nil
      case 124: // right arrow
        self.handler?(.right)
        return nil
      case 36, 76: // Return / keypad Enter
        self.handler?(.accept)
        return nil
      case 53: // Escape
        self.handler?(.back)
        return nil
      default:
        return event
      }
    }
  }

  func stop() {
    if let monitor {
      NSEvent.removeMonitor(monitor)
      self.monitor = nil
    }
    handler = nil
  }
}
#endif
'''

    command_anchor = "private enum ZoneFrontEndCommand: Equatable {\n  case up\n  case down\n  case left\n  case right\n  case accept\n  case back\n}\n"
    source = replace_once(
        source,
        command_anchor,
        command_anchor + keyboard_monitor,
        "macOS keyboard monitor insertion",
    )

    state_old = '''private struct ZoneTitleScreen: View {
  @ObservedObject var session: ZoneAppSession
  @StateObject private var controller = ZoneFrontEndInputMonitor()
  @State private var selection = 0
  @FocusState private var keyboardFocused: Bool
'''
    state_new = '''private struct ZoneTitleScreen: View {
  @ObservedObject var session: ZoneAppSession
  @StateObject private var controller = ZoneFrontEndInputMonitor()
  @State private var selection = 0
  #if os(macOS)
  @StateObject private var keyboard = ZoneMacFrontEndKeyboardMonitor()
  #else
  @FocusState private var keyboardFocused: Bool
  #endif
'''
    source = replace_once(source, state_old, state_new, "title input state")

    modifier_old = '''    .focusable()
    .focused($keyboardFocused)
    .onAppear {
      selection = min(selection, itemCount - 1)
      DispatchQueue.main.async { keyboardFocused = true }
      controller.start(handleController)
    }
    .onDisappear { controller.stop() }
    .onKeyPress(.upArrow) {
      moveSelection(-1)
      return .handled
    }
    .onKeyPress(.downArrow) {
      moveSelection(1)
      return .handled
    }
    .onKeyPress(.return) {
      activateSelection()
      return .handled
    }
'''
    modifier_new = '''    #if os(macOS)
    .onAppear {
      selection = min(selection, itemCount - 1)
      controller.start(handleController)
      keyboard.start(handleKeyboard)
    }
    .onDisappear {
      keyboard.stop()
      controller.stop()
    }
    #else
    .focusable()
    .focused($keyboardFocused)
    .onAppear {
      selection = min(selection, itemCount - 1)
      DispatchQueue.main.async { keyboardFocused = true }
      controller.start(handleController)
    }
    .onDisappear { controller.stop() }
    .onKeyPress(.upArrow) {
      moveSelection(-1)
      return .handled
    }
    .onKeyPress(.downArrow) {
      moveSelection(1)
      return .handled
    }
    .onKeyPress(.leftArrow) {
      moveSelection(-1)
      return .handled
    }
    .onKeyPress(.rightArrow) {
      moveSelection(1)
      return .handled
    }
    .onKeyPress(.return) {
      activateSelection()
      return .handled
    }
    #endif
'''
    source = replace_once(source, modifier_old, modifier_new, "title focus/key modifiers")

    handler_anchor = '''  private func handleController(_ command: ZoneFrontEndCommand) {
    switch command {
    case .up, .left:
      moveSelection(-1)
    case .down, .right:
      moveSelection(1)
    case .accept:
      activateSelection()
    case .back:
      break
    }
  }
'''
    handler_new = handler_anchor + '''
  #if os(macOS)
  private func handleKeyboard(_ command: ZoneFrontEndCommand) {
    switch command {
    case .up, .left:
      moveSelection(-1)
    case .down, .right:
      moveSelection(1)
    case .accept:
      activateSelection()
    case .back:
      break
    }
  }
  #endif
'''
    source = replace_once(source, handler_anchor, handler_new, "title keyboard handler")

    return source


def self_test() -> None:
    fixture = '''import Foundation\nimport GameController\nimport ImageIO\nimport SwiftUI\n\nprivate enum ZoneFrontEndCommand: Equatable {\n  case up\n  case down\n  case left\n  case right\n  case accept\n  case back\n}\n\n/// Event-driven front-end controller input.\n// Milestone 1.11.1 front-end frame-pacing hotfix\nprivate final class ZoneFrontEndInputMonitor: ObservableObject {\n  init() {\n    GCController.startWirelessControllerDiscovery(completionHandler: nil)\n    let nc = NotificationCenter.default\n    _ = nc\n  }\n}\n\nprivate struct ZoneTitleScreen: View {\n  @ObservedObject var session: ZoneAppSession\n  @StateObject private var controller = ZoneFrontEndInputMonitor()\n  @State private var selection = 0\n  @FocusState private var keyboardFocused: Bool\n\n  var body: some View {\n    Text("x")\n    .focusable()\n    .focused($keyboardFocused)\n    .onAppear {\n      selection = min(selection, itemCount - 1)\n      DispatchQueue.main.async { keyboardFocused = true }\n      controller.start(handleController)\n    }\n    .onDisappear { controller.stop() }\n    .onKeyPress(.upArrow) {\n      moveSelection(-1)\n      return .handled\n    }\n    .onKeyPress(.downArrow) {\n      moveSelection(1)\n      return .handled\n    }\n    .onKeyPress(.return) {\n      activateSelection()\n      return .handled\n    }\n  }\n\n  private func handleController(_ command: ZoneFrontEndCommand) {\n    switch command {\n    case .up, .left:\n      moveSelection(-1)\n    case .down, .right:\n      moveSelection(1)\n    case .accept:\n      activateSelection()\n    case .back:\n      break\n    }\n  }\n}\n\n// Milestone 1.11.2 predecoded interpolated title ship\n'''
    patched = patch_source(fixture)
    assert MARKER in patched
    assert "#if !os(macOS)\n    GCController.startWirelessControllerDiscovery" in patched
    assert "ZoneMacFrontEndKeyboardMonitor" in patched
    assert "@StateObject private var keyboard" in patched
    assert "keyboard.start(handleKeyboard)" in patched
    assert patch_source(patched) == patched
    print("1.11.3 patcher self-test: PASS")


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
