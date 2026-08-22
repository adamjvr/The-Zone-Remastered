import Foundation

final class ZoneInputRouter {
  enum Action: Hashable {
    case left, right, thrust, fire, equipmentUp, equipmentDown, select, pause, save
  }

  private let lock = NSLock()
  private var keyboard: Set<Action> = []
  private var touch: Set<Action> = []
  private var pausePulse = false

  private func set(_ action: Action, pressed: Bool, in set: inout Set<Action>) {
    if action == .pause {
      // Pause is an edge-triggered command, not a held gameplay state.  Only
      // the first transition from up -> down produces a pulse.  This also
      // suppresses macOS key-repeat generated keyDown events.
      if pressed && !set.contains(.pause) { pausePulse = true }
    }
    if pressed { set.insert(action) } else { set.remove(action) }
  }

  func setKeyboard(_ action: Action, pressed: Bool) {
    lock.lock()
    defer { lock.unlock() }
    set(action, pressed: pressed, in: &keyboard)
  }

  func setTouch(_ action: Action, pressed: Bool) {
    lock.lock()
    defer { lock.unlock() }
    set(action, pressed: pressed, in: &touch)
  }

  func clearKeyboard() {
    lock.lock()
    keyboard.removeAll()
    lock.unlock()
  }

  func sample(controller: ZoneControllerManager) -> ZoneInput {
    lock.lock()
    let active = keyboard.union(touch)
    let localPausePulse = pausePulse
    pausePulse = false
    lock.unlock()

    var c = controller.sample()
    let left = active.contains(.left)
    let right = active.contains(.right)
    if left != right { c.turn = left ? -1 : 1 }
    if active.contains(.thrust) { c.thrust = 1 }
    if active.contains(.fire) { c.fire = 1 }
    if active.contains(.equipmentUp) { c.equipment_up = 1 }
    if active.contains(.equipmentDown) { c.equipment_down = 1 }
    if active.contains(.select) { c.select = 1 }
    if localPausePulse { c.pause = 1 }
    if active.contains(.save) { c.save = 1 }
    return c
  }
}
