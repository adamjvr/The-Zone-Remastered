import Foundation
import SwiftUI

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

private enum ZoneAppScreen: Equatable {
  case title
  case game
  case controls
  case preferences
  case credits
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

  func startNewGame() {
    gameIdentity = UUID()
    screen = .game
  }

  func returnToTitle() {
    screen = .title
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
    Group {
      switch session.screen {
      case .title:
        ZoneTitleScreen(session: session)
      case .controls:
        ZoneControlsScreen(session: session)
      case .preferences:
        ZonePreferencesScreen(session: session)
      case .credits:
        ZoneCreditsScreen(session: session)
      case .game:
        ZoneContentView(
          showHUD: session.showHUD,
          showControlHints: session.showControlHints,
          showTouchControls: session.showTouchControls,
          onReturnToTitle: session.returnToTitle
        )
        .id(session.gameIdentity)
      }
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
  }
}

private struct ZoneTitleScreen: View {
  @ObservedObject var session: ZoneAppSession

  var body: some View {
    GeometryReader { proxy in
      ZStack {
        ZoneTitleBackdrop()

        ViewThatFits(in: .horizontal) {
          HStack(spacing: max(36, proxy.size.width * 0.055)) {
            ZoneTitleIdentity(compact: false)
              .frame(maxWidth: .infinity)
            menu
              .frame(width: min(390, max(300, proxy.size.width * 0.31)))
          }
          .padding(.horizontal, max(34, proxy.size.width * 0.07))
          .padding(.vertical, 36)

          VStack(spacing: 24) {
            ZoneTitleIdentity(compact: true)
            menu.frame(maxWidth: 430)
          }
          .padding(28)
        }
      }
    }
    .ignoresSafeArea()
  }

  private var menu: some View {
    VStack(alignment: .leading, spacing: 13) {
      Text("MAIN TERMINAL")
        .font(.system(size: 13, weight: .semibold, design: .monospaced))
        .tracking(3)
        .foregroundStyle(.white.opacity(0.55))
        .padding(.bottom, 4)

      Button("NEW GAME") { session.startNewGame() }
        .keyboardShortcut(.return, modifiers: [])
        .buttonStyle(ZoneMenuButtonStyle(prominent: true))

      Button("CONTROLS") { session.screen = .controls }
        .buttonStyle(ZoneMenuButtonStyle())

      Button("PREFERENCES") { session.screen = .preferences }
        .buttonStyle(ZoneMenuButtonStyle())

      Button("CREDITS") { session.screen = .credits }
        .buttonStyle(ZoneMenuButtonStyle())

      #if os(macOS)
      Button("QUIT") { NSApplication.shared.terminate(nil) }
        .buttonStyle(ZoneMenuButtonStyle())
      #endif

      Divider().overlay(.white.opacity(0.12)).padding(.vertical, 5)

      Text("CLASSIC CORE • NATIVE 720 Hz MOTION")
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .tracking(1.3)
        .foregroundStyle(.white.opacity(0.42))

      Text("Direct developer boot: ZONE_BOOT_DIRECT=1")
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(.white.opacity(0.28))
    }
    .padding(24)
    .background(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(Color.black.opacity(0.62))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 18, style: .continuous)
        .stroke(
          LinearGradient(
            colors: [.cyan.opacity(0.55), .white.opacity(0.14), .purple.opacity(0.36)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
    )
    .shadow(color: .cyan.opacity(0.10), radius: 28)
  }
}

private struct ZoneTitleIdentity: View {
  let compact: Bool

  var body: some View {
    VStack(spacing: compact ? 8 : 18) {
      ZoneRotatingShip()
        .frame(width: compact ? 136 : 260, height: compact ? 136 : 260)

      VStack(spacing: compact ? 0 : 2) {
        Text("THE")
          .font(.system(size: compact ? 18 : 26, weight: .medium, design: .monospaced))
          .tracking(compact ? 10 : 15)
          .foregroundStyle(.white.opacity(0.72))

        Text("ZONE")
          .font(.system(size: compact ? 58 : 100, weight: .black, design: .rounded))
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
          .font(.system(size: compact ? 11 : 15, weight: .semibold, design: .monospaced))
          .foregroundStyle(.purple.opacity(0.90))
      }

      if !compact {
        Text("ENTER THE ZONE")
          .font(.system(size: 12, weight: .medium, design: .monospaced))
          .tracking(4)
          .foregroundStyle(.white.opacity(0.38))
      }
    }
  }
}

private struct ZoneRotatingShip: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
      let phase = reduceMotion ? 0 : Int(timeline.date.timeIntervalSinceReferenceDate * 5.0)
      let frame = ((phase % 48) + 48) % 48
      let resource = String(format: "Spri_%05d", 1000 + frame)

      ZStack {
        Circle()
          .fill(
            RadialGradient(
              colors: [.cyan.opacity(0.18), .purple.opacity(0.07), .clear],
              center: .center,
              startRadius: 2,
              endRadius: 120
            )
          )

        Circle()
          .stroke(.cyan.opacity(0.22), lineWidth: 1)
          .padding(20)

        Circle()
          .trim(from: 0.08, to: 0.72)
          .stroke(.purple.opacity(0.42), style: StrokeStyle(lineWidth: 2, dash: [4, 8]))
          .padding(8)
          .rotationEffect(.degrees(Double(frame) * 7.5))

        ZoneBundledSpriteImage(resource: resource)
          .padding(38)
          .shadow(color: .cyan.opacity(0.75), radius: 10)
      }
    }
    .aspectRatio(1, contentMode: .fit)
  }
}

private struct ZoneBundledSpriteImage: View {
  let resource: String

  @ViewBuilder var body: some View {
    #if os(macOS)
    if let url = Bundle.main.url(forResource: resource, withExtension: "png", subdirectory: "Sprites"),
       let image = NSImage(contentsOf: url) {
      Image(nsImage: image)
        .resizable()
        .interpolation(.none)
        .scaledToFit()
    } else {
      Color.clear
    }
    #else
    if let url = Bundle.main.url(forResource: resource, withExtension: "png", subdirectory: "Sprites"),
       let image = UIImage(contentsOfFile: url.path) {
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
        colors: [.cyan.opacity(0.11), .clear],
        center: .leading,
        startRadius: 10,
        endRadius: 520
      )

      ZoneTitleStarfield()
        .opacity(0.95)

      Rectangle()
        .fill(
          LinearGradient(
            colors: [.clear, .black.opacity(0.18), .black.opacity(0.52)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
    }
  }
}

private struct ZoneTitleStarfield: View {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { timeline in
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

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 15, weight: .bold, design: .monospaced))
      .tracking(1.6)
      .foregroundStyle(prominent ? Color.black : Color.white.opacity(0.92))
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 18)
      .padding(.vertical, 13)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(
            prominent
              ? Color(red: 0.66, green: 0.93, blue: 1.0).opacity(configuration.isPressed ? 0.72 : 0.95)
              : Color.white.opacity(configuration.isPressed ? 0.12 : 0.045)
          )
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(prominent ? .cyan.opacity(0.9) : .white.opacity(0.16), lineWidth: 1)
      )
      .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
      .animation(.easeOut(duration: 0.08), value: configuration.isPressed)
  }
}

private struct ZoneFrontEndPage<Content: View>: View {
  let eyebrow: String
  let title: String
  let onBack: () -> Void
  let content: Content

  init(
    eyebrow: String,
    title: String,
    onBack: @escaping () -> Void,
    @ViewBuilder content: () -> Content
  ) {
    self.eyebrow = eyebrow
    self.title = title
    self.onBack = onBack
    self.content = content()
  }

  var body: some View {
    ZStack {
      ZoneTitleBackdrop()

      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text(eyebrow)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .tracking(3)
            .foregroundStyle(.cyan.opacity(0.65))
          Text(title)
            .font(.system(size: 36, weight: .black, design: .rounded))
            .foregroundStyle(.white)
        }

        ScrollView {
          content
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        Button("BACK") { onBack() }
          .keyboardShortcut(.cancelAction)
          .buttonStyle(ZoneMenuButtonStyle())
          .frame(maxWidth: 280)
      }
      .padding(30)
      .frame(maxWidth: 720, maxHeight: 680, alignment: .topLeading)
      .background(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .fill(Color.black.opacity(0.72))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 20, style: .continuous)
          .stroke(.cyan.opacity(0.24), lineWidth: 1)
      )
      .padding(28)
    }
    .ignoresSafeArea()
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
  #if os(macOS)
  @StateObject private var router = ZoneInputRouter()
  #endif

  var body: some View {
    ZoneFrontEndPage(eyebrow: "SYSTEM", title: "CONTROLS", onBack: session.returnToTitle) {
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
        ZoneInfoRow(label: "CONTROLLER", value: "Apple GameController-supported pads are accepted as an alternate input path.")
        #else
        ZoneInfoRow(label: "TOUCH", value: "On-screen flight controls appear when no controller is connected.")
        ZoneInfoRow(label: "CONTROLLER", value: "Apple GameController-supported pads are first-class input on iPad.")
        ZoneInfoRow(label: "KEYBOARD", value: "External keyboards use the shared semantic input layer where supported.")
        #endif

        Divider().overlay(.white.opacity(0.12)).padding(.vertical, 8)
        Text("Gameplay bindings remain outside ZoneCore; changing an input mapping cannot change Classic simulation behavior.")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.white.opacity(0.46))
      }
    }
  }
}

private struct ZonePreferencesScreen: View {
  @ObservedObject var session: ZoneAppSession

  var body: some View {
    ZoneFrontEndPage(eyebrow: "SYSTEM", title: "PREFERENCES", onBack: session.returnToTitle) {
      VStack(alignment: .leading, spacing: 16) {
        ZonePreferenceToggle(
          title: "SHOW HUD",
          detail: "Score, shields, ammunition, speed, bases, enemies and wave.",
          isOn: $session.showHUD
        )

        #if os(macOS)
        ZonePreferenceToggle(
          title: "SHOW CONTROL HINTS",
          detail: "Show the keyboard/controller reminder along the bottom of gameplay.",
          isOn: $session.showControlHints
        )
        #else
        ZonePreferenceToggle(
          title: "SHOW TOUCH CONTROLS",
          detail: "Show on-screen controls when no physical controller is connected.",
          isOn: $session.showTouchControls
        )
        #endif

        Divider().overlay(.white.opacity(0.12)).padding(.vertical, 8)

        ZoneInfoRow(label: "SIMULATION", value: "720 Hz native motion / 60 Hz recovered Classic decision boundaries")
        ZoneInfoRow(label: "DISPLAY", value: "Presentation follows the active display refresh rate independently of game speed.")
        ZoneInfoRow(label: "ACCESSIBILITY", value: "System Reduce Motion freezes the rotating title ship and animated starfield.")
      }
    }
  }
}

private struct ZonePreferenceToggle: View {
  let title: String
  let detail: String
  @Binding var isOn: Bool

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
    .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
  }
}

private struct ZoneCreditsScreen: View {
  @ObservedObject var session: ZoneAppSession

  var body: some View {
    ZoneFrontEndPage(eyebrow: "ARCHIVE", title: "CREDITS", onBack: session.returnToTitle) {
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
        Text("Milestone 1.8 — Native Front-End & Title Screen")
          .font(.system(size: 11, weight: .semibold, design: .monospaced))
          .foregroundStyle(.cyan.opacity(0.66))
      }
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
      Text("PAUSED")
        .font(.system(size: 42, weight: .bold, design: .monospaced))

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
    .background(.black.opacity(0.90))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(.white.opacity(0.22), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .shadow(radius: 24)
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

  var body: some View {
    VStack(spacing: 16) {
      Text("PAUSED")
        .font(.system(size: 46, weight: .black, design: .monospaced))

      Button("RESUME") { router.pulsePause() }
        .buttonStyle(ZoneMenuButtonStyle(prominent: true))

      Button("TITLE SCREEN") { onReturnToTitle() }
        .buttonStyle(ZoneMenuButtonStyle())
    }
    .foregroundStyle(.white)
    .padding(26)
    .frame(maxWidth: 390)
    .background(Color.black.opacity(0.88), in: RoundedRectangle(cornerRadius: 18))
    .overlay(
      RoundedRectangle(cornerRadius: 18)
        .stroke(.cyan.opacity(0.28), lineWidth: 1)
    )
    .shadow(radius: 24)
    .padding(28)
  }
}
#endif
