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
      } else if !host.hud.playerAlive {
        Text("SHIP DESTROYED").font(.system(size: 36, weight: .bold, design: .monospaced))
          .foregroundStyle(.white).padding(20).background(.black.opacity(0.55))
      }
    }
  }
}
