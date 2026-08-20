import SwiftUI

struct ZoneContentView: View {
  @StateObject private var host = ZoneGameHost()
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      ZoneMetalView(host: host).ignoresSafeArea()
      VStack {
        HStack(spacing: 22) {
          Text("SCORE \(host.hud.score)")
          Text("SHIELDS \(host.hud.shields)%")
          Text("AMMO \(host.hud.ammo)")
          Spacer()
          Text("WAVE \(host.hud.wave)")
        }.font(.system(.headline, design: .monospaced)).foregroundStyle(.white).padding(14)
          .background(.black.opacity(0.35))
        Spacer()
        #if os(macOS)
          HStack {
            Text("←/→ ROTATE   SPACE THRUST   OPTION FIRE")
            Spacer()
            Text(host.hasController ? "CONTROLLER CONNECTED" : "KEYBOARD CANONICAL")
          }.font(.system(.caption, design: .monospaced)).foregroundStyle(.white.opacity(0.75))
            .padding(10)
        #else
          if !host.hasController { ZoneTouchControls(router: host.input) }
        #endif
      }
      if host.hud.paused {
        Text("PAUSED").font(.system(size: 52, weight: .bold, design: .monospaced)).foregroundStyle(
          .white
        ).padding(24).background(.black.opacity(0.65))
      }
    }
  }
}
