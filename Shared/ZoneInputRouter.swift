import Combine
import Foundation

/// Platform input terminates here as semantic actions. ZoneCore never sees
/// physical key codes, which lets macOS bindings change without altering
/// recovered gameplay behavior.
final class ZoneInputRouter: ObservableObject {
  enum Action: String, CaseIterable, Hashable, Identifiable {
    case left, right, thrust, fire, equipmentUp, equipmentDown, select, pause, save

    var id: String { rawValue }

    var displayName: String {
      switch self {
      case .left: return "Rotate Left"
      case .right: return "Rotate Right"
      case .thrust: return "Thrust"
      case .fire: return "Fire"
      case .equipmentUp: return "Equipment Up"
      case .equipmentDown: return "Equipment Down"
      case .select: return "Select / Use"
      case .pause: return "Pause"
      case .save: return "Classic Save"
      }
    }
  }

  /// Classic Mac defaults expressed as macOS virtual key codes.
  /// Option/Command bindings are treated as modifier families so either side
  /// of the keyboard continues to behave like the original mapping.
  static let canonicalBindings: [Action: UInt16] = [
    .left: 123,
    .right: 124,
    .thrust: 49,
    .fire: 58,       // Option
    .equipmentUp: 126,
    .equipmentDown: 125,
    .select: 55,     // Command
    .pause: 53,      // Escape
    .save: 65,       // keypad decimal
  ]

  @Published private(set) var keyboardBindings: [Action: UInt16]
  @Published private(set) var rebindingAction: Action? = nil

  private let defaultsKey = "TheZone.KeyboardBindings.v1"
  private let defaults: UserDefaults
  private let lock = NSLock()
  private var keyboard: Set<Action> = []
  private var touch: Set<Action> = []
  private var pausePulse = false

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    var loaded = Self.canonicalBindings
    if let saved = defaults.dictionary(forKey: defaultsKey) {
      for action in Action.allCases {
        if let number = saved[action.rawValue] as? NSNumber {
          loaded[action] = number.uint16Value
        }
      }
    }
    keyboardBindings = loaded
  }

  private func set(_ action: Action, pressed: Bool, in set: inout Set<Action>) {
    if action == .pause {
      // Pause is an edge-triggered command, never a held gameplay state.
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

  func pulsePause() {
    lock.lock()
    keyboard.removeAll()
    pausePulse = true
    lock.unlock()
  }

  var isRebinding: Bool { rebindingAction != nil }

  func beginRebinding(_ action: Action) {
    clearKeyboard()
    rebindingAction = action
  }

  func cancelRebinding() {
    rebindingAction = nil
  }

  /// Captures exactly one physical key. If that key is already assigned, the
  /// two actions swap keys so every gameplay action remains reachable.
  @discardableResult
  func captureRebindKey(_ keyCode: UInt16) -> Bool {
    guard let action = rebindingAction else { return false }
    var next = keyboardBindings
    let oldCode = next[action] ?? Self.canonicalBindings[action]!

    if let conflicting = Action.allCases.first(where: {
      $0 != action && Self.samePhysicalFamily(next[$0], keyCode)
    }) {
      next[conflicting] = oldCode
    }
    next[action] = keyCode
    keyboardBindings = next
    rebindingAction = nil
    clearKeyboard()
    persistBindings()
    return true
  }

  func resetKeyboardBindings() {
    keyboardBindings = Self.canonicalBindings
    rebindingAction = nil
    clearKeyboard()
    persistBindings()
  }

  func bindingLabel(for action: Action) -> String {
    Self.keyLabel(keyboardBindings[action] ?? Self.canonicalBindings[action]!)
  }

  func setKeyboardKey(_ keyCode: UInt16, pressed: Bool) {
    guard let action = action(forKeyCode: keyCode) else { return }
    setKeyboard(action, pressed: pressed)
  }

  private func action(forKeyCode keyCode: UInt16) -> Action? {
    Action.allCases.first { action in
      Self.samePhysicalFamily(keyboardBindings[action], keyCode)
    }
  }

  private func persistBindings() {
    var saved: [String: Int] = [:]
    for action in Action.allCases {
      saved[action.rawValue] = Int(keyboardBindings[action] ?? Self.canonicalBindings[action]!)
    }
    defaults.set(saved, forKey: defaultsKey)
  }

  private static func modifierFamily(_ code: UInt16) -> Int? {
    switch code {
    case 54, 55: return 1  // Command
    case 56, 60: return 2  // Shift
    case 58, 61: return 3  // Option
    case 59, 62: return 4  // Control
    default: return nil
    }
  }

  private static func samePhysicalFamily(_ bound: UInt16?, _ pressed: UInt16) -> Bool {
    guard let bound else { return false }
    if bound == pressed { return true }
    guard let a = modifierFamily(bound), let b = modifierFamily(pressed) else { return false }
    return a == b
  }

  static func keyLabel(_ code: UInt16) -> String {
    switch code {
    case 123: return "←"
    case 124: return "→"
    case 125: return "↓"
    case 126: return "↑"
    case 49: return "Space"
    case 53: return "Esc"
    case 54, 55: return "Command"
    case 56, 60: return "Shift"
    case 58, 61: return "Option"
    case 59, 62: return "Control"
    case 65: return "Keypad ."
    case 36: return "Return"
    case 48: return "Tab"
    case 51: return "Delete"
    case 117: return "Forward Delete"
    case 115: return "Home"
    case 119: return "End"
    case 116: return "Page Up"
    case 121: return "Page Down"
    case 122: return "F1"
    case 120: return "F2"
    case 99: return "F3"
    case 118: return "F4"
    case 96: return "F5"
    case 97: return "F6"
    case 98: return "F7"
    case 100: return "F8"
    case 101: return "F9"
    case 109: return "F10"
    case 103: return "F11"
    case 111: return "F12"
    default:
      // ANSI virtual-key positions used by macOS. This is display-only; input
      // routing always uses the stable virtual key code itself.
      let names: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
        23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/",
        45: "N", 46: "M", 47: ".", 50: "`",
      ]
      return names[code] ?? "Key \(code)"
    }
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
