import Combine
import Foundation

struct ZoneHUDSnapshot {
  var score = 0
  var shields = 100
  var wave = 1
  var ammo = 2
  var bases = 0
  var enemies = 0
  var paused = false
}

final class ZoneGameHost: ObservableObject {
  let input = ZoneInputRouter()
  let controllers = ZoneControllerManager()
  let audio = ZoneAudioEngine()
  @Published var hud = ZoneHUDSnapshot()
  @Published var hasController = false
  let game: OpaquePointer
  private var cancellables: Set<AnyCancellable> = []
  private var hudDivider = 0

  init() {
    guard let g = zone_game_create(0x5A4F_4E45) else { fatalError("Unable to create ZoneCore") }
    game = g
    controllers.$hasController.receive(on: RunLoop.main).sink { [weak self] in
      self?.hasController = $0
    }.store(in: &cancellables)
  }
  deinit { zone_game_destroy(game) }

  func step() {
    let sampled = input.sample(controller: controllers)
    zone_game_step(game, sampled)
    var events = Array(repeating: ZoneAudioEvent(), count: 16)
    let n = events.withUnsafeMutableBufferPointer {
      zone_game_drain_audio(game, $0.baseAddress, Int32($0.count))
    }
    if n > 0 { for i in 0..<Int(n) { audio.play(events[i]) } }
    hudDivider += 1
    if hudDivider >= 6 {
      hudDivider = 0
      let h = zone_game_hud(game)
      DispatchQueue.main.async { [weak self] in
        self?.hud = ZoneHUDSnapshot(
          score: Int(h.score), shields: Int(h.shields), wave: Int(h.wave), ammo: Int(h.ammo),
          bases: Int(h.bases), enemies: Int(h.enemies), paused: h.paused != 0)
      }
    }
  }
}
