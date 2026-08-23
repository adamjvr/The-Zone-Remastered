import Combine
import Foundation

struct ZoneHUDSnapshot {
  var score = 0
  var shields = 100
  var wave = 1
  var ammo = 2
  var bases = 0
  var enemies = 0
  var speed: Float = 0
  var maximumSpeed: Float = 25
  var playerAlive = true
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

  // Milestone 1.2 attribution is opt-in. Normal gameplay pays only this cached
  // boolean branch and otherwise follows the Milestone 1.1 host behavior.
  private let diagnosticsEnabled = ProcessInfo.processInfo.environment["ZONE_PERF_DIAGNOSTICS"] == "1"
  private var diagnosticsFrame: UInt64 = 0

  init() {
    guard let g = zone_game_create(0x5A4F_4E45) else { fatalError("Unable to create ZoneCore") }
    game = g
    controllers.$hasController.receive(on: RunLoop.main).sink { [weak self] in
      self?.hasController = $0
    }.store(in: &cancellables)
  }
  deinit { zone_game_destroy(game) }

  func step() {
    if !diagnosticsEnabled {
      // Keep the accepted Milestone 1.1 path compact and behavior-identical.
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
            bases: Int(h.bases), enemies: Int(h.enemies),
            speed: h.speed, maximumSpeed: h.maximum_speed,
            playerAlive: h.player_alive != 0, paused: h.paused != 0)
        }
      }
      return
    }

    diagnosticsFrame &+= 1
    let totalStart = ProcessInfo.processInfo.systemUptime

    let inputStart = ProcessInfo.processInfo.systemUptime
    let sampled = input.sample(controller: controllers)
    let inputMS = (ProcessInfo.processInfo.systemUptime - inputStart) * 1000

    let coreStart = ProcessInfo.processInfo.systemUptime
    zone_game_step(game, sampled)
    let coreMS = (ProcessInfo.processInfo.systemUptime - coreStart) * 1000

    var events = Array(repeating: ZoneAudioEvent(), count: 16)
    let drainStart = ProcessInfo.processInfo.systemUptime
    let n = events.withUnsafeMutableBufferPointer {
      zone_game_drain_audio(game, $0.baseAddress, Int32($0.count))
    }
    let drainMS = (ProcessInfo.processInfo.systemUptime - drainStart) * 1000

    var audioMS = 0.0
    var audioMaxMS = 0.0
    var audioMaxType: Int32 = 0
    if n > 0 {
      let audioStart = ProcessInfo.processInfo.systemUptime
      for i in 0..<Int(n) {
        let oneStart = ProcessInfo.processInfo.systemUptime
        audio.play(events[i])
        let oneMS = (ProcessInfo.processInfo.systemUptime - oneStart) * 1000
        if oneMS > audioMaxMS {
          audioMaxMS = oneMS
          audioMaxType = events[i].type
        }
      }
      audioMS = (ProcessInfo.processInfo.systemUptime - audioStart) * 1000
    }

    let hudStart = ProcessInfo.processInfo.systemUptime
    var hudPublished = 0
    hudDivider += 1
    if hudDivider >= 6 {
      hudDivider = 0
      hudPublished = 1
      let h = zone_game_hud(game)
      DispatchQueue.main.async { [weak self] in
        self?.hud = ZoneHUDSnapshot(
          score: Int(h.score), shields: Int(h.shields), wave: Int(h.wave), ammo: Int(h.ammo),
          bases: Int(h.bases), enemies: Int(h.enemies),
          speed: h.speed, maximumSpeed: h.maximum_speed,
          playerAlive: h.player_alive != 0, paused: h.paused != 0)
      }
    }
    let hudMS = (ProcessInfo.processInfo.systemUptime - hudStart) * 1000
    let totalMS = (ProcessInfo.processInfo.systemUptime - totalStart) * 1000

    // Match the renderer's existing slow-step gate. Only slow diagnostic steps
    // pay for the extra state probes/string formatting below.
    if totalMS > 4.0 {
      var dominant = "input"
      var dominantMS = inputMS
      if coreMS > dominantMS { dominant = "core"; dominantMS = coreMS }
      if drainMS > dominantMS { dominant = "drain"; dominantMS = drainMS }
      if audioMS > dominantMS { dominant = "audio"; dominantMS = audioMS }
      if hudMS > dominantMS { dominant = "hud"; dominantMS = hudMS }

      let h = zone_game_hud(game)
      let world = zone_game_world_object_count(game)
      let shots = zone_game_active_projectiles(game)
      let hostile = zone_game_active_hostile_projectiles(game)
      let tick = zone_game_debug_behavior_tick(game)

      let detail = String(
        format: "[ZonePerf][host-detail] frame=%llu total=%.3f input=%.3f core=%.3f drain=%.3f audio=%.3f audioMax=%.3f audioType=%d hud=%.3f hudPub=%d events=%d dominantMS=%.3f wave=%d bases=%d enemies=%d world=%d shots=%d hostile=%d tick=%u",
        diagnosticsFrame,
        totalMS, inputMS, coreMS, drainMS, audioMS, audioMaxMS, audioMaxType,
        hudMS, hudPublished, Int(n), dominantMS,
        h.wave, h.bases, h.enemies, world, shots, hostile, tick
      )
      print(detail + " dominant=\(dominant)")
    }
  }
}
