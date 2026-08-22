import Combine
import Foundation
import GameController

/// Controller policy for The Zone Remastered:
/// - Never whitelist vendors or model names.
/// - Consume Apple's semantic physical-input profile, so system remapping is honored.
/// - Prefer the controller the player used most recently.
/// - Classic ZoneCore quantizes analog input back to the original digital actions.
final class ZoneControllerManager: ObservableObject {
  @Published private(set) var hasController = false
  private var observers: [NSObjectProtocol] = []

  private let pauseLock = NSLock()
  private var menuWasPressed = false
  private var lastMenuPulseUptime: TimeInterval = -1
  private let menuDebounceSeconds: TimeInterval = 0.20

  init() {
    GCController.startWirelessControllerDiscovery(completionHandler: nil)
    let nc = NotificationCenter.default
    observers.append(
      nc.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
        self?.refresh(resetPauseEdge: true)
      })
    observers.append(
      nc.addObserver(forName: .GCControllerDidDisconnect, object: nil, queue: .main) {
        [weak self] _ in self?.refresh(resetPauseEdge: true)
      })
    observers.append(
      nc.addObserver(
        forName: .GCControllerUserCustomizationsDidChange,
        object: nil,
        queue: .main
      ) { [weak self] _ in self?.refresh(resetPauseEdge: false) })
    refresh(resetPauseEdge: true)
  }

  deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

  private func refresh(resetPauseEdge: Bool) {
    hasController = !GCController.controllers().isEmpty
    if resetPauseEdge {
      pauseLock.lock()
      menuWasPressed = false
      lastMenuPulseUptime = -1
      pauseLock.unlock()
    }
  }

  private func activeController() -> GCController? {
    GCController.current ?? GCController.controllers().first
  }

  private func buttonValue(_ name: String, in profile: GCPhysicalInputProfile) -> Float {
    profile.buttons[name]?.value ?? 0
  }

  private func buttonPressed(_ name: String, in profile: GCPhysicalInputProfile) -> Bool {
    profile.buttons[name]?.isPressed ?? false
  }

  private func menuPausePulse(_ pressed: Bool) -> UInt8 {
    pauseLock.lock()
    defer { pauseLock.unlock() }

    let risingEdge = pressed && !menuWasPressed
    menuWasPressed = pressed
    guard risingEdge else { return 0 }

    // Some controller/profile combinations can briefly bounce the Menu state.
    // Reject a second rising edge inside a small human-impossible interval.
    let now = ProcessInfo.processInfo.systemUptime
    if lastMenuPulseUptime >= 0 && now - lastMenuPulseUptime < menuDebounceSeconds {
      return 0
    }
    lastMenuPulseUptime = now
    return 1
  }

  func sample() -> ZoneInput {
    var out = ZoneInput()
    guard let controller = activeController() else {
      _ = menuPausePulse(false)
      return out
    }

    let profile = controller.physicalInputProfile
    let stickX = profile.dpads[GCInputLeftThumbstick]?.xAxis.value ?? 0
    let dpadX = profile.dpads[GCInputDirectionPad]?.xAxis.value ?? 0
    out.turn = abs(stickX) > 0.22 ? stickX : dpadX

    out.thrust = max(
      buttonValue(GCInputButtonA, in: profile),
      buttonValue(GCInputRightTrigger, in: profile)
    )
    out.fire =
      (buttonPressed(GCInputButtonX, in: profile)
        || buttonPressed(GCInputRightShoulder, in: profile)) ? 1 : 0
    out.equipment_up = buttonPressed(GCInputButtonY, in: profile) ? 1 : 0
    out.equipment_down = buttonPressed(GCInputButtonB, in: profile) ? 1 : 0
    out.select = buttonPressed(GCInputLeftShoulder, in: profile) ? 1 : 0
    out.pause = menuPausePulse(buttonPressed(GCInputButtonMenu, in: profile))

    if profile.buttons[GCInputButtonA] == nil, let micro = controller.microGamepad {
      out.thrust = max(out.thrust, max(0, micro.dpad.yAxis.value))
      out.fire = micro.buttonA.isPressed ? 1 : out.fire
      out.select = micro.buttonX.isPressed ? 1 : out.select
    }
    return out
  }
}
