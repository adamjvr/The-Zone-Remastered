import SwiftUI

struct ZoneContentView: View {
  @StateObject private var host = ZoneGameHost()

  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      ZoneMetalView(host: host).ignoresSafeArea()

      VStack {
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

        Spacer()

        #if os(macOS)
          ZoneKeyboardHint(router: host.input, hasController: host.hasController)
        #else
          if !host.hasController { ZoneTouchControls(router: host.input) }
        #endif
      }

      if host.hud.paused {
        #if os(macOS)
          ZonePauseMenu(router: host.input)
        #else
          Text("PAUSED")
            .font(.system(size: 52, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(24)
            .background(.black.opacity(0.65))
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
  import AppKit

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
      .frame(width: 500)
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
#endif
