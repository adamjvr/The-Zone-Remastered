import Foundation
import GameController
import ImageIO
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

private enum ZoneAppScreen: Equatable, Hashable {
  case title
  case game
  case controls
  case preferences
  case credits
}

private enum ZoneFrontEndCommand: Equatable {
  case up
  case down
  case left
  case right
  case accept
  case back
}

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

/// Event-driven front-end controller input. Gameplay keeps using
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
    // Milestone 1.11.3 macOS key-window input isolation: do not run
    // wireless controller discovery on a keyboard-driven Mac title
    // screen. Existing connected controllers remain discoverable.
    #if !os(macOS)
    GCController.startWirelessControllerDiscovery(completionHandler: nil)
    #endif
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

private final class ZoneAppSession: ObservableObject {
  @Published var screen: ZoneAppScreen
  @Published var gameIdentity = UUID()

  @Published var showHUD: Bool {
    didSet { defaults.set(showHUD, forKey: Self.showHUDKey) }
  }
  @Published var showControlHints: Bool {
    didSet { defaults.set(showControlHints, forKey: Self.showControlHintsKey) }
  }
  @Published var showTouchControls: Bool {
    didSet { defaults.set(showTouchControls, forKey: Self.showTouchControlsKey) }
  }

  private let defaults = UserDefaults.standard
  private static let showHUDKey = "ZoneFrontEnd.showHUD"
  private static let showControlHintsKey = "ZoneFrontEnd.showControlHints"
  private static let showTouchControlsKey = "ZoneFrontEnd.showTouchControls"

  init() {
    showHUD = Self.boolPreference(Self.showHUDKey, defaultValue: true)
    showControlHints = Self.boolPreference(Self.showControlHintsKey, defaultValue: true)
    showTouchControls = Self.boolPreference(Self.showTouchControlsKey, defaultValue: true)
    screen = ProcessInfo.processInfo.environment["ZONE_BOOT_DIRECT"] == "1" ? .game : .title
  }

  func show(_ destination: ZoneAppScreen) {
    withAnimation(.easeInOut(duration: 0.18)) {
      screen = destination
    }
  }

  func startNewGame() {
    gameIdentity = UUID()
    show(.game)
  }

  func returnToTitle() {
    show(.title)
  }

  private static func boolPreference(_ key: String, defaultValue: Bool) -> Bool {
    let defaults = UserDefaults.standard
    guard defaults.object(forKey: key) != nil else { return defaultValue }
    return defaults.bool(forKey: key)
  }
}

struct ZoneAppShell: View {
  @StateObject private var session = ZoneAppSession()

  var body: some View {
    ZStack {
      switch session.screen {
      case .title:
        ZoneTitleScreen(session: session)
          .transition(.opacity.combined(with: .scale(scale: 0.985)))
      case .controls:
        ZoneControlsScreen(session: session)
          .transition(.opacity.combined(with: .move(edge: .trailing)))
      case .preferences:
        ZonePreferencesScreen(session: session)
          .transition(.opacity.combined(with: .move(edge: .trailing)))
      case .credits:
        ZoneCreditsScreen(session: session)
          .transition(.opacity.combined(with: .move(edge: .trailing)))
      case .game:
        ZoneContentView(
          showHUD: session.showHUD,
          showControlHints: session.showControlHints,
          showTouchControls: session.showTouchControls,
          onReturnToTitle: session.returnToTitle
        )
        .id(session.gameIdentity)
        .transition(.opacity)
      }
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
    .animation(.easeInOut(duration: 0.18), value: session.screen)
  }
}

private struct ZoneTitleScreen: View {
  @ObservedObject var session: ZoneAppSession
  @StateObject private var controller = ZoneFrontEndInputMonitor()
  @State private var selection = 0
  #if os(macOS)
  @StateObject private var keyboard = ZoneMacFrontEndKeyboardMonitor()
  #else
  @FocusState private var keyboardFocused: Bool
  #endif

  private var itemCount: Int {
    #if os(macOS)
    return 5
    #else
    return 4
    #endif
  }

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        ZoneTitleBackdrop()
          .ignoresSafeArea()

        ViewThatFits(in: .horizontal) {
          HStack(spacing: max(30, proxy.size.width * 0.05)) {
            ZoneTitleIdentity(compact: proxy.size.height < 700)
              .frame(maxWidth: .infinity)

            menu
              .frame(width: min(410, max(310, proxy.size.width * 0.32)))
          }
          .padding(.horizontal, max(30, proxy.size.width * 0.065))
          .padding(.vertical, proxy.size.height < 650 ? 22 : 36)

          ScrollView {
            VStack(spacing: proxy.size.height < 760 ? 14 : 24) {
              ZoneTitleIdentity(compact: true)
              menu.frame(maxWidth: 460)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 26)
            .padding(.vertical, 24)
          }
          .scrollIndicators(.hidden)
        }
      }
    }
    #if os(macOS)
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
  }

  private var menu: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text("MAIN TERMINAL")
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .tracking(3)
            .foregroundStyle(.white.opacity(0.62))
          Text("FLIGHT COMPUTER ONLINE")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(.cyan.opacity(0.52))
        }
        Spacer()
        Circle()
          .fill(.cyan.opacity(0.88))
          .frame(width: 7, height: 7)
          .shadow(color: .cyan.opacity(0.8), radius: 6)
      }
      .padding(.bottom, 5)

      ZoneMenuActionButton(
        title: "NEW GAME",
        selected: selection == 0,
        prominent: true
      ) {
        session.startNewGame()
      }

      ZoneMenuActionButton(title: "CONTROLS", selected: selection == 1) {
        session.show(.controls)
      }

      ZoneMenuActionButton(title: "PREFERENCES", selected: selection == 2) {
        session.show(.preferences)
      }

      ZoneMenuActionButton(title: "CREDITS", selected: selection == 3) {
        session.show(.credits)
      }

      #if os(macOS)
      ZoneMenuActionButton(title: "QUIT", selected: selection == 4) {
        NSApplication.shared.terminate(nil)
      }
      #endif

      Divider().overlay(.white.opacity(0.12)).padding(.vertical, 4)

      HStack(spacing: 7) {
        ZoneStatusPill(text: "CLASSIC RULES")
        ZoneStatusPill(text: "720 HZ MOTION")
        ZoneStatusPill(text: "NATIVE METAL")
      }

      if controller.hasController {
        Text("D-PAD / STICK  NAVIGATE   •   PRIMARY  SELECT")
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .tracking(0.6)
          .foregroundStyle(.cyan.opacity(0.52))
      } else {
        #if os(macOS)
        Text("↑ ↓  NAVIGATE   •   RETURN  SELECT")
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .tracking(0.6)
          .foregroundStyle(.white.opacity(0.36))
        #else
        Text("TOUCH TO SELECT   •   CONTROLLER READY")
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .tracking(0.6)
          .foregroundStyle(.white.opacity(0.36))
        #endif
      }
    }
    .padding(22)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.black.opacity(0.68))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(
          LinearGradient(
            colors: [.cyan.opacity(0.62), .white.opacity(0.13), .purple.opacity(0.42)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    )
    .shadow(color: .cyan.opacity(0.12), radius: 30)
  }

  private func moveSelection(_ delta: Int) {
    let count = max(itemCount, 1)
    selection = (selection + delta + count) % count
  }

  private func activateSelection() {
    switch selection {
    case 0: session.startNewGame()
    case 1: session.show(.controls)
    case 2: session.show(.preferences)
    case 3: session.show(.credits)
    #if os(macOS)
    case 4: NSApplication.shared.terminate(nil)
    #endif
    default: break
    }
  }

  private func handleController(_ command: ZoneFrontEndCommand) {
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
}

private struct ZoneMenuActionButton: View {
  let title: String
  let selected: Bool
  var prominent = false
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Text(selected ? "▶" : " ")
          .font(.system(size: 10, weight: .black, design: .monospaced))
          .foregroundStyle(selected ? .cyan : .clear)
          .frame(width: 12)
        Text(title)
        Spacer()
        if selected {
          Text("READY")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(1.2)
            .foregroundStyle(prominent ? Color.black.opacity(0.62) : .cyan.opacity(0.62))
        }
      }
    }
    .buttonStyle(ZoneMenuButtonStyle(prominent: prominent, selected: selected))
  }
}

private struct ZoneStatusPill: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.system(size: 7.5, weight: .bold, design: .monospaced))
      .tracking(0.5)
      .foregroundStyle(.white.opacity(0.56))
      .padding(.horizontal, 7)
      .padding(.vertical, 5)
      .background(Color.white.opacity(0.035), in: Capsule())
      .overlay(Capsule().stroke(.white.opacity(0.09), lineWidth: 1))
  }
}

private struct ZoneTitleIdentity: View {
  let compact: Bool

  var body: some View {
    VStack(spacing: compact ? 7 : 16) {
      ZoneRotatingShip()
        .frame(width: compact ? 132 : 252, height: compact ? 132 : 252)

      VStack(spacing: compact ? 0 : 2) {
        Text("THE")
          .font(.system(size: compact ? 17 : 25, weight: .medium, design: .monospaced))
          .tracking(compact ? 10 : 15)
          .foregroundStyle(.white.opacity(0.72))

        Text("ZONE")
          .font(.system(size: compact ? 56 : 96, weight: .black, design: .rounded))
          .tracking(compact ? 3 : 7)
          .foregroundStyle(
            LinearGradient(
              colors: [.white, Color(red: 0.62, green: 0.92, blue: 1.0), .white.opacity(0.74)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .shadow(color: .cyan.opacity(0.55), radius: compact ? 8 : 16)

        Text("R E M A S T E R E D")
          .font(.system(size: compact ? 10 : 14, weight: .semibold, design: .monospaced))
          .tracking(compact ? 0.5 : 1.0)
          .foregroundStyle(.purple.opacity(0.90))
      }

      if !compact {
        Text("ENTER THE ZONE")
          .font(.system(size: 11, weight: .medium, design: .monospaced))
          .tracking(4)
          .foregroundStyle(.white.opacity(0.38))
      }
    }
  }
}

private struct ZoneRotatingShip: View {
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

private struct ZoneTitleBackdrop: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.005, green: 0.01, blue: 0.03),
          Color(red: 0.01, green: 0.025, blue: 0.07),
          Color(red: 0.025, green: 0.008, blue: 0.055),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      RadialGradient(
        colors: [.cyan.opacity(0.12), .clear],
        center: .leading,
        startRadius: 10,
        endRadius: 540
      )

      ZoneTitleStarfield()
        .opacity(0.95)

      ZoneScanlines()

      Rectangle()
        .fill(
          LinearGradient(
            colors: [.clear, .black.opacity(0.16), .black.opacity(0.52)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
    }
  }
}

private struct ZoneScanlines: View {
  var body: some View {
    Canvas { context, size in
      var path = Path()
      var y: CGFloat = 0
      while y <= size.height {
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: size.width, y: y))
        y += 5
      }
      context.stroke(path, with: .color(.white.opacity(0.018)), lineWidth: 0.5)
    }
    .allowsHitTesting(false)
  }
}

private struct ZoneTitleStarfield: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(paused: reduceMotion)) { timeline in
      Canvas { context, size in
        let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
        let height = max(Double(size.height), 1.0)

        for i in 0..<96 {
          let xUnit = Double((i * 73 + 19) % 997) / 997.0
          let ySeed = Double((i * 151 + 47) % 991) / 991.0
          let speed = 1.5 + Double(i % 5) * 0.7
          let y = fmod(ySeed * height + time * speed, height)
          let pulse = 0.26 + 0.48 * (0.5 + 0.5 * sin(time * (0.45 + Double(i % 7) * 0.05) + Double(i)))
          let radius = CGFloat(0.7 + Double(i % 3) * 0.42)
          let rect = CGRect(
            x: CGFloat(xUnit) * size.width,
            y: CGFloat(y),
            width: radius,
            height: radius
          )
          context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(pulse)))
        }
      }
    }
  }
}

private struct ZoneMenuButtonStyle: ButtonStyle {
  var prominent = false
  var selected = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 15, weight: .bold, design: .monospaced))
      .tracking(1.5)
      .foregroundStyle(prominent ? Color.black : Color.white.opacity(0.94))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 15)
      .padding(.vertical, 12)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(background(configuration: configuration))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(border, lineWidth: selected ? 1.6 : 1)
      )
      .shadow(color: selected ? .cyan.opacity(0.14) : .clear, radius: 9)
      .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
      .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
      .animation(.easeOut(duration: 0.12), value: selected)
  }

  private func background(configuration: Configuration) -> Color {
    if prominent {
      return Color(red: 0.66, green: 0.93, blue: 1.0)
        .opacity(configuration.isPressed ? 0.72 : (selected ? 0.98 : 0.88))
    }
    if selected {
      return .cyan.opacity(configuration.isPressed ? 0.15 : 0.095)
    }
    return .white.opacity(configuration.isPressed ? 0.12 : 0.045)
  }

  private var border: Color {
    if prominent { return .cyan.opacity(selected ? 1.0 : 0.72) }
    return selected ? .cyan.opacity(0.76) : .white.opacity(0.15)
  }
}

private struct ZoneFrontEndPage<Content: View>: View {
  let eyebrow: String
  let title: String
  let onBack: () -> Void
  let controllerConnected: Bool
  let content: Content

  init(
    eyebrow: String,
    title: String,
    onBack: @escaping () -> Void,
    controllerConnected: Bool = false,
    @ViewBuilder content: () -> Content
  ) {
    self.eyebrow = eyebrow
    self.title = title
    self.onBack = onBack
    self.controllerConnected = controllerConnected
    self.content = content()
  }

  var body: some View {
    ZStack {
      ZoneTitleBackdrop()
        .ignoresSafeArea()

      VStack(alignment: .leading, spacing: 18) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow)
              .font(.system(size: 11, weight: .semibold, design: .monospaced))
              .tracking(3)
              .foregroundStyle(.cyan.opacity(0.68))
            Text(title)
              .font(.system(size: 36, weight: .black, design: .rounded))
              .foregroundStyle(.white)
          }
          Spacer()
          Text("THE ZONE // SYSTEM")
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(1.5)
            .foregroundStyle(.white.opacity(0.24))
            .padding(.top, 8)
        }

        ScrollView {
          content
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)

        HStack(alignment: .center) {
          Button("BACK") { onBack() }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(ZoneMenuButtonStyle(selected: false))
            .frame(maxWidth: 250)

          Spacer()

          if controllerConnected {
            Text("SECONDARY / MENU  BACK")
              .font(.system(size: 8.5, weight: .medium, design: .monospaced))
              .foregroundStyle(.cyan.opacity(0.46))
          }
        }
      }
      .padding(28)
      .frame(maxWidth: 760, maxHeight: 690, alignment: .topLeading)
      .background(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .fill(Color.black.opacity(0.74))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(.cyan.opacity(0.28), lineWidth: 1)
      )
      .shadow(color: .black.opacity(0.42), radius: 28, y: 12)
      .padding(26)
    }
  }
}

private struct ZoneInfoRow: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .top, spacing: 18) {
      Text(label)
        .font(.system(size: 13, weight: .bold, design: .monospaced))
        .foregroundStyle(.cyan.opacity(0.82))
        .frame(width: 148, alignment: .leading)
      Text(value)
        .font(.system(size: 13, design: .monospaced))
        .foregroundStyle(.white.opacity(0.76))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.vertical, 6)
  }
}

private struct ZoneControlsScreen: View {
  @ObservedObject var session: ZoneAppSession
  @StateObject private var controller = ZoneFrontEndInputMonitor()
  @FocusState private var keyboardFocused: Bool
  #if os(macOS)
  @StateObject private var router = ZoneInputRouter()
  #endif

  var body: some View {
    ZoneFrontEndPage(
      eyebrow: "SYSTEM",
      title: "CONTROLS",
      onBack: session.returnToTitle,
      controllerConnected: controller.hasController
    ) {
      VStack(alignment: .leading, spacing: 14) {
        #if os(macOS)
        ZoneInfoRow(label: "KEYBOARD", value: "Canonical desktop input. Bindings can be changed from the in-game pause menu.")
        ZoneInfoRow(label: "ROTATE", value: "\(router.bindingLabel(for: .left)) / \(router.bindingLabel(for: .right))")
        ZoneInfoRow(label: "THRUST", value: router.bindingLabel(for: .thrust))
        ZoneInfoRow(label: "FIRE", value: router.bindingLabel(for: .fire))
        ZoneInfoRow(label: "EQUIPMENT", value: "\(router.bindingLabel(for: .equipmentUp)) / \(router.bindingLabel(for: .equipmentDown))")
        ZoneInfoRow(label: "SELECT / USE", value: router.bindingLabel(for: .select))
        ZoneInfoRow(label: "PAUSE", value: router.bindingLabel(for: .pause))
        ZoneInfoRow(label: "CLASSIC SAVE", value: router.bindingLabel(for: .save))
        ZoneInfoRow(label: "CONTROLLER", value: "D-pad or left stick navigates menus. Primary activates. Secondary/Menu backs out. Gameplay continues through Apple's semantic GameController profile.")
        #else
        ZoneInfoRow(label: "TOUCH", value: "On-screen flight controls appear when no controller is connected.")
        ZoneInfoRow(label: "CONTROLLER", value: "D-pad or left stick navigates menus. Primary activates. Secondary/Menu backs out. Apple GameController-supported pads remain first-class gameplay input.")
        ZoneInfoRow(label: "KEYBOARD", value: "External keyboards can navigate the front end with arrows, Return and Escape where iPadOS exposes hardware-key events.")
        #endif

        Divider().overlay(.white.opacity(0.12)).padding(.vertical, 8)
        Text("Gameplay bindings remain outside ZoneCore; changing an input mapping cannot change Classic simulation behavior.")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.white.opacity(0.46))
      }
    }
    .focusable()
    .focused($keyboardFocused)
    .onAppear {
      DispatchQueue.main.async { keyboardFocused = true }
      controller.start { command in
        if command == .back { session.returnToTitle() }
      }
    }
    .onDisappear { controller.stop() }
    .onKeyPress(.escape) {
      session.returnToTitle()
      return .handled
    }
  }
}

private struct ZonePreferencesScreen: View {
  @ObservedObject var session: ZoneAppSession
  @StateObject private var controller = ZoneFrontEndInputMonitor()
  @State private var selection = 0
  @FocusState private var keyboardFocused: Bool

  private let optionCount = 2

  var body: some View {
    ZoneFrontEndPage(
      eyebrow: "SYSTEM",
      title: "PREFERENCES",
      onBack: session.returnToTitle,
      controllerConnected: controller.hasController
    ) {
      VStack(alignment: .leading, spacing: 16) {
        ZonePreferenceToggle(
          title: "SHOW HUD",
          detail: "Score, shields, ammunition, speed, bases, enemies and wave.",
          isOn: $session.showHUD,
          selected: selection == 0
        )

        #if os(macOS)
        ZonePreferenceToggle(
          title: "SHOW CONTROL HINTS",
          detail: "Show the keyboard/controller reminder along the bottom of gameplay.",
          isOn: $session.showControlHints,
          selected: selection == 1
        )
        #else
        ZonePreferenceToggle(
          title: "SHOW TOUCH CONTROLS",
          detail: "Show on-screen controls when no physical controller is connected.",
          isOn: $session.showTouchControls,
          selected: selection == 1
        )
        #endif

        Divider().overlay(.white.opacity(0.12)).padding(.vertical, 8)

        ZoneInfoRow(label: "SIMULATION", value: "720 Hz native motion / 60 Hz recovered Classic decision boundaries")
        ZoneInfoRow(label: "DISPLAY", value: "Presentation follows the active display refresh rate independently of game speed.")
        ZoneInfoRow(label: "ACCESSIBILITY", value: "System Reduce Motion freezes the rotating title ship and animated starfield.")

        if controller.hasController {
          Text("D-PAD / STICK selects a setting. LEFT / RIGHT / PRIMARY toggles it.")
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.cyan.opacity(0.48))
            .padding(.top, 4)
        }
      }
    }
    .focusable()
    .focused($keyboardFocused)
    .onAppear {
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
      toggleSelection()
      return .handled
    }
    .onKeyPress(.rightArrow) {
      toggleSelection()
      return .handled
    }
    .onKeyPress(.return) {
      toggleSelection()
      return .handled
    }
    .onKeyPress(.escape) {
      session.returnToTitle()
      return .handled
    }
  }

  private func moveSelection(_ delta: Int) {
    selection = (selection + delta + optionCount) % optionCount
  }

  private func toggleSelection() {
    if selection == 0 {
      session.showHUD.toggle()
    } else {
      #if os(macOS)
      session.showControlHints.toggle()
      #else
      session.showTouchControls.toggle()
      #endif
    }
  }

  private func handleController(_ command: ZoneFrontEndCommand) {
    switch command {
    case .up:
      moveSelection(-1)
    case .down:
      moveSelection(1)
    case .left, .right, .accept:
      toggleSelection()
    case .back:
      session.returnToTitle()
    }
  }
}

private struct ZonePreferenceToggle: View {
  let title: String
  let detail: String
  @Binding var isOn: Bool
  var selected = false

  var body: some View {
    Toggle(isOn: $isOn) {
      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 14, weight: .bold, design: .monospaced))
          .foregroundStyle(.white)
        Text(detail)
          .font(.system(size: 11, design: .monospaced))
          .foregroundStyle(.white.opacity(0.48))
      }
    }
    .toggleStyle(.switch)
    .tint(.cyan)
    .padding(14)
    .background(
      selected ? Color.cyan.opacity(0.075) : Color.white.opacity(0.035),
      in: RoundedRectangle(cornerRadius: 10)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(selected ? .cyan.opacity(0.62) : .white.opacity(0.07), lineWidth: selected ? 1.5 : 1)
    )
    .shadow(color: selected ? .cyan.opacity(0.10) : .clear, radius: 8)
    .animation(.easeOut(duration: 0.12), value: selected)
  }
}

private struct ZoneCreditsScreen: View {
  @ObservedObject var session: ZoneAppSession
  @StateObject private var controller = ZoneFrontEndInputMonitor()
  @FocusState private var keyboardFocused: Bool

  var body: some View {
    ZoneFrontEndPage(
      eyebrow: "ARCHIVE",
      title: "CREDITS",
      onBack: session.returnToTitle,
      controllerConnected: controller.hasController
    ) {
      VStack(alignment: .leading, spacing: 18) {
        Text("THE ZONE REMASTERED")
          .font(.system(size: 18, weight: .black, design: .monospaced))
          .foregroundStyle(.white)

        Text("A native-source reconstruction of TheZone 1.5.1, rebuilt from recovered behavior, resources and reverse-engineered PowerPC game logic.")
          .font(.system(size: 13, design: .monospaced))
          .foregroundStyle(.white.opacity(0.72))

        ZoneInfoRow(label: "ENGINE", value: "Portable ZoneCore C simulation with native SwiftUI / Metal Apple hosts")
        ZoneInfoRow(label: "ASSETS", value: "Recovered Classic Spri sprite resources and original sound resources")
        ZoneInfoRow(label: "TARGETS", value: "Native macOS and native iPadOS; Linux remains a planned target")
        ZoneInfoRow(label: "MISSION", value: "Observable Classic fidelity first; optional remaster enhancements afterward")

        Divider().overlay(.white.opacity(0.12)).padding(.vertical, 8)
        Text("Milestone 1.8.1 — Front-End Polish & Navigation")
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .foregroundStyle(.cyan.opacity(0.66))
      }
    }
    .focusable()
    .focused($keyboardFocused)
    .onAppear {
      DispatchQueue.main.async { keyboardFocused = true }
      controller.start { command in
        if command == .back { session.returnToTitle() }
      }
    }
    .onDisappear { controller.stop() }
    .onKeyPress(.escape) {
      session.returnToTitle()
      return .handled
    }
  }
}

struct ZoneContentView: View {
  @StateObject private var host = ZoneGameHost()
  let showHUD: Bool
  let showControlHints: Bool
  let showTouchControls: Bool
  let onReturnToTitle: () -> Void

  init(
    showHUD: Bool = true,
    showControlHints: Bool = true,
    showTouchControls: Bool = true,
    onReturnToTitle: @escaping () -> Void = {}
  ) {
    self.showHUD = showHUD
    self.showControlHints = showControlHints
    self.showTouchControls = showTouchControls
    self.onReturnToTitle = onReturnToTitle
  }

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      ZoneMetalView(host: host).ignoresSafeArea()

      VStack {
        if showHUD {
          HStack(spacing: 18) {
            Text("SCORE \(host.hud.score)")
            Text("SHIELDS \(host.hud.shields)%")
            Text("AMMO \(host.hud.ammo)")
            Text(String(format: "SPEED %.0f/%.0f", host.hud.speed, host.hud.maximumSpeed))
            Text("BASES \(host.hud.bases)")
            Text("ENEMIES \(host.hud.enemies)")
            Spacer()
            Text("WAVE \(host.hud.wave)")
          }
          .font(.system(.headline, design: .monospaced))
          .foregroundStyle(.white)
          .padding(14)
          .background(.black.opacity(0.35))
        }

        Spacer()

        #if os(macOS)
        if showControlHints {
          ZoneKeyboardHint(router: host.input, hasController: host.hasController)
        }
        #else
        if showTouchControls && !host.hasController { ZoneTouchControls(router: host.input) }
        #endif
      }

      if host.hud.paused {
        #if os(macOS)
        ZonePauseMenu(router: host.input, onReturnToTitle: onReturnToTitle)
        #else
        ZonePadPauseMenu(router: host.input, onReturnToTitle: onReturnToTitle)
        #endif
      } else if !host.hud.playerAlive {
        Text("SHIP DESTROYED")
          .font(.system(size: 36, weight: .bold, design: .monospaced))
          .foregroundStyle(.white)
          .padding(20)
          .background(.black.opacity(0.55))
      }
    }
  }
}

#if os(macOS)
private struct ZoneKeyboardHint: View {
  @ObservedObject var router: ZoneInputRouter
  let hasController: Bool

  var body: some View {
    HStack {
      Text(
        "\(router.bindingLabel(for: .left))/\(router.bindingLabel(for: .right)) ROTATE   "
          + "\(router.bindingLabel(for: .thrust)) THRUST   "
          + "\(router.bindingLabel(for: .fire)) FIRE"
      )
      Spacer()
      Text(hasController ? "CONTROLLER CONNECTED" : "KEYBOARD CANONICAL")
    }
    .font(.system(.caption, design: .monospaced))
    .foregroundStyle(.white.opacity(0.75))
    .padding(10)
  }
}

private struct ZonePauseMenu: View {
  @ObservedObject var router: ZoneInputRouter
  let onReturnToTitle: () -> Void

  var body: some View {
    VStack(spacing: 14) {
      VStack(spacing: 3) {
        Text("SYSTEM // FLIGHT HOLD")
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .tracking(2)
          .foregroundStyle(.cyan.opacity(0.58))
        Text("PAUSED")
          .font(.system(size: 42, weight: .black, design: .monospaced))
      }

      Text("KEYBOARD CONTROLS")
        .font(.system(.headline, design: .monospaced))
        .foregroundStyle(.secondary)

      VStack(spacing: 6) {
        ForEach(ZoneInputRouter.Action.allCases) { action in
          HStack {
            Text(action.displayName)
              .font(.system(.body, design: .monospaced))
            Spacer()
            Button {
              router.beginRebinding(action)
            } label: {
              Text(
                router.rebindingAction == action
                  ? "PRESS A KEY…"
                  : router.bindingLabel(for: action)
              )
              .font(.system(.body, design: .monospaced))
              .frame(minWidth: 112)
            }
            .buttonStyle(.bordered)
          }
        }
      }

      if router.rebindingAction != nil {
        Text("Press the replacement key now. Existing assignments swap automatically.")
          .font(.system(.caption, design: .monospaced))
          .foregroundStyle(.secondary)
      }

      HStack {
        Button("Reset Defaults") { router.resetKeyboardBindings() }
          .buttonStyle(.bordered)
        if router.rebindingAction != nil {
          Button("Cancel Rebind") { router.cancelRebinding() }
            .buttonStyle(.bordered)
        }
        Spacer()
        Button("Title Screen") {
          router.cancelRebinding()
          router.clearKeyboard()
          onReturnToTitle()
        }
        .buttonStyle(.bordered)
        Button("Resume") {
          router.cancelRebinding()
          router.pulsePause()
        }
        .keyboardShortcut(.return, modifiers: [])
        .buttonStyle(.borderedProminent)
      }

      ZonePauseKeyCapture(router: router)
        .frame(width: 1, height: 1)
        .opacity(0.001)
    }
    .foregroundStyle(.white)
    .padding(24)
    .frame(width: 540)
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.95), Color(red: 0.015, green: 0.035, blue: 0.07).opacity(0.94)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .stroke(.cyan.opacity(0.30), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 14))
    .shadow(color: .black.opacity(0.55), radius: 28, y: 12)
    .onDisappear {
      router.cancelRebinding()
      router.clearKeyboard()
    }
  }
}

private final class ZonePauseKeyCaptureView: NSView {
  weak var router: ZoneInputRouter?
  override var acceptsFirstResponder: Bool { true }

  override func keyDown(with event: NSEvent) {
    guard let router else { return }
    ZoneMacKeyboardEventRouter.keyDown(event, router: router)
  }

  override func keyUp(with event: NSEvent) {
    guard let router else { return }
    ZoneMacKeyboardEventRouter.keyUp(event, router: router)
  }

  override func flagsChanged(with event: NSEvent) {
    guard let router else { return }
    ZoneMacKeyboardEventRouter.flagsChanged(event, router: router)
  }
}

private struct ZonePauseKeyCapture: NSViewRepresentable {
  let router: ZoneInputRouter

  func makeNSView(context: Context) -> ZonePauseKeyCaptureView {
    let view = ZonePauseKeyCaptureView()
    view.router = router
    DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
    return view
  }

  func updateNSView(_ nsView: ZonePauseKeyCaptureView, context: Context) {
    nsView.router = router
    DispatchQueue.main.async { nsView.window?.makeFirstResponder(nsView) }
  }
}
#else
private struct ZonePadPauseMenu: View {
  @ObservedObject var router: ZoneInputRouter
  let onReturnToTitle: () -> Void
  @StateObject private var controller = ZoneFrontEndInputMonitor()
  @State private var selection = 0
  @FocusState private var keyboardFocused: Bool

  var body: some View {
    VStack(spacing: 16) {
      VStack(spacing: 3) {
        Text("SYSTEM // FLIGHT HOLD")
          .font(.system(size: 9, weight: .semibold, design: .monospaced))
          .tracking(2)
          .foregroundStyle(.cyan.opacity(0.58))
        Text("PAUSED")
          .font(.system(size: 46, weight: .black, design: .monospaced))
      }

      ZoneMenuActionButton(title: "RESUME", selected: selection == 0, prominent: true) {
        router.pulsePause()
      }

      ZoneMenuActionButton(title: "TITLE SCREEN", selected: selection == 1) {
        onReturnToTitle()
      }

      if controller.hasController {
        Text("D-PAD / STICK  NAVIGATE   •   PRIMARY  SELECT")
          .font(.system(size: 8.5, weight: .medium, design: .monospaced))
          .foregroundStyle(.cyan.opacity(0.46))
      }
    }
    .foregroundStyle(.white)
    .padding(26)
    .frame(maxWidth: 410)
    .background(
      LinearGradient(
        colors: [Color.black.opacity(0.95), Color(red: 0.015, green: 0.035, blue: 0.07).opacity(0.94)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      ),
      in: RoundedRectangle(cornerRadius: 18)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .stroke(.cyan.opacity(0.32), lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.55), radius: 28, y: 12)
    .padding(28)
    .focusable()
    .focused($keyboardFocused)
    .onAppear {
      DispatchQueue.main.async { keyboardFocused = true }
      controller.start(handleController)
    }
    .onDisappear { controller.stop() }
    .onKeyPress(.upArrow) {
      selection = 0
      return .handled
    }
    .onKeyPress(.downArrow) {
      selection = 1
      return .handled
    }
    .onKeyPress(.return) {
      activateSelection()
      return .handled
    }
    .onKeyPress(.escape) {
      router.pulsePause()
      return .handled
    }
  }

  private func activateSelection() {
    if selection == 0 {
      router.pulsePause()
    } else {
      onReturnToTitle()
    }
  }

  private func handleController(_ command: ZoneFrontEndCommand) {
    switch command {
    case .up, .left:
      selection = 0
    case .down, .right:
      selection = 1
    case .accept:
      activateSelection()
    case .back:
      router.pulsePause()
    }
  }
}
#endif
