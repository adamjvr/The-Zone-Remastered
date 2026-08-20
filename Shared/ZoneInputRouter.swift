import Foundation

final class ZoneInputRouter {
  enum Action: Hashable {
    case left, right, thrust, fire, equipmentUp, equipmentDown, select, pause, save
  }
  private let lock = NSLock()
  private var keyboard: Set<Action> = []
  private var touch: Set<Action> = []

  func setKeyboard(_ action: Action, pressed: Bool) {
    lock.lock()
    defer { lock.unlock() }
    if pressed { keyboard.insert(action) } else { keyboard.remove(action) }
  }
  func setTouch(_ action: Action, pressed: Bool) {
    lock.lock()
    defer { lock.unlock() }
    if pressed { touch.insert(action) } else { touch.remove(action) }
  }
  func sample(controller: ZoneControllerManager) -> ZoneInput {
    lock.lock()
    let active = keyboard.union(touch)
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
    if active.contains(.pause) { c.pause = 1 }
    if active.contains(.save) { c.save = 1 }
    return c
  }
}
