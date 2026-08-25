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

// ZONE_TIMEBASE_BEGIN
struct ZoneTimebasePlan {
  let classicSteps: Int
  let masterTicksElapsed: UInt64
  let rebased: Bool
  let catchUpClamped: Bool
}

struct ZoneTimebase {
  // 720 Hz is the master scheduling grid for the high-refresh architecture.
  // Milestone 1.4 does NOT run Classic gameplay 720 times/second: twelve
  // master ticks schedule one authoritative Classic step (60 Hz). Later work
  // can promote continuous dynamics onto the master grid while leaving
  // recovered AI/RNG/timer semantics on their proven Classic cadence.
  static let masterHz: UInt64 = 720
  static let classicHz: UInt64 = 60
  static let masterTicksPerClassicStep: UInt64 = masterHz / classicHz
  static let maximumPresentationGap: TimeInterval = 0.250
  static let maximumClassicStepsPerPresentation = 8

  private var originTime: TimeInterval?
  private var lastPresentationTime: TimeInterval?
  private var emittedMasterTicks: UInt64 = 0
  private var pendingMasterTicks: UInt64 = 0

  mutating func reset(at now: TimeInterval) {
    originTime = now
    lastPresentationTime = now
    emittedMasterTicks = 0
    pendingMasterTicks = 0
  }

  mutating func plan(at now: TimeInterval) -> ZoneTimebasePlan {
    guard let origin = originTime, let last = lastPresentationTime else {
      reset(at: now)
      // Preserve the established contract that the first visible draw advances
      // the game once, then continue from monotonic elapsed time.
      return ZoneTimebasePlan(
        classicSteps: 1, masterTicksElapsed: 0, rebased: false, catchUpClamped: false)
    }

    let presentationGap = now - last
    if presentationGap < 0 || presentationGap > Self.maximumPresentationGap {
      // Do not simulate a giant backlog after sleep/backgrounding/debugger
      // stops. Rebase and advance one Classic step, exactly as a fresh first
      // presentation would.
      reset(at: now)
      return ZoneTimebasePlan(
        classicSteps: 1, masterTicksElapsed: 0, rebased: true, catchUpClamped: false)
    }
    lastPresentationTime = now

    let elapsed = max(0, now - origin)
    let targetDouble = (elapsed * Double(Self.masterHz)).rounded()
    let targetMasterTicks = targetDouble <= 0 ? 0 : UInt64(targetDouble)

    if targetMasterTicks < emittedMasterTicks {
      reset(at: now)
      return ZoneTimebasePlan(
        classicSteps: 1, masterTicksElapsed: 0, rebased: true, catchUpClamped: false)
    }

    let newlyElapsed = targetMasterTicks - emittedMasterTicks
    emittedMasterTicks = targetMasterTicks
    pendingMasterTicks &+= newlyElapsed

    var due = Int(pendingMasterTicks / Self.masterTicksPerClassicStep)
    pendingMasterTicks %= Self.masterTicksPerClassicStep

    var clamped = false
    if due > Self.maximumClassicStepsPerPresentation {
      due = Self.maximumClassicStepsPerPresentation
      clamped = true
      // Wall-clock time has already been consumed into emittedMasterTicks.
      // Dropping excessive backlog is intentional: a long stall must not turn
      // into a visible multi-frame spiral of death.
    }

    return ZoneTimebasePlan(
      classicSteps: due,
      masterTicksElapsed: newlyElapsed,
      rebased: false,
      catchUpClamped: clamped)
  }
}
// ZONE_TIMEBASE_END

final class ZoneGameHost: ObservableObject {
  let input = ZoneInputRouter()
  let controllers = ZoneControllerManager()
  let audio = ZoneAudioEngine()
  @Published var hud = ZoneHUDSnapshot()
  @Published var hasController = false
  let game: OpaquePointer
  private var cancellables: Set<AnyCancellable> = []
  private var hudDivider = 0
  private var timebase = ZoneTimebase()

  // Milestone 1.2 attribution remains opt-in. Normal gameplay pays only cached
  // boolean branches; Milestone 1.4 adds timebase diagnostics only when enabled.
  private let diagnosticsEnabled = ProcessInfo.processInfo.environment["ZONE_PERF_DIAGNOSTICS"] == "1"
  private let highRateDynamicsEnabled = ProcessInfo.processInfo.environment["ZONE_HIGH_RATE_DYNAMICS"] != "0"
  private var reportedDynamicsMode = false
  private var diagnosticsFrame: UInt64 = 0

  init() {
    guard let g = zone_game_create(0x5A4F_4E45) else { fatalError("Unable to create ZoneCore") }
    game = g
    controllers.$hasController.receive(on: RunLoop.main).sink { [weak self] in
      self?.hasController = $0
    }.store(in: &cancellables)
  }
  deinit { zone_game_destroy(game) }

  /// Advance authoritative Classic simulation according to monotonic time,
  /// independently of how often Metal asks us to present. Returns the number
  /// of 60-Hz Classic steps actually executed for this presentation callback.
  @discardableResult
  func advance(presentationTime: TimeInterval) -> Int {
    let plan = timebase.plan(at: presentationTime)
    if diagnosticsEnabled && (plan.rebased || plan.catchUpClamped || plan.classicSteps > 1) {
      print(
        "[ZonePerf][timebase] master=\(plan.masterTicksElapsed) classicSteps=\(plan.classicSteps) " +
        "rebased=\(plan.rebased ? 1 : 0) clamped=\(plan.catchUpClamped ? 1 : 0)"
      )
    }
    if highRateDynamicsEnabled {
      return advanceHighRate(plan: plan)
    }
    if plan.classicSteps > 0 {
      for _ in 0..<plan.classicSteps { step() }
    }
    return plan.classicSteps
  }

  /// Milestone 1.5 native dynamics path. The monotonic scheduler yields master
  /// ticks at 720 Hz; ZoneCore integrates real positions on each tick while
  /// retaining recovered Classic decisions/collision boundaries every 12 ticks.
  private func advanceHighRate(plan: ZoneTimebasePlan) -> Int {
    let maxMasterTicks = Int(
      ZoneTimebase.masterTicksPerClassicStep * UInt64(ZoneTimebase.maximumClassicStepsPerPresentation))
    var masterTicks = Int(plan.masterTicksElapsed)

    // First draw/rebase intentionally represents one complete Classic interval.
    if masterTicks == 0 && plan.classicSteps > 0 {
      masterTicks = plan.classicSteps * Int(ZoneTimebase.masterTicksPerClassicStep)
    }
    let dynamicsClamped = masterTicks > maxMasterTicks
    if dynamicsClamped { masterTicks = maxMasterTicks }
    guard masterTicks > 0 else { return 0 }

    if diagnosticsEnabled && !reportedDynamicsMode {
      reportedDynamicsMode = true
      print("[ZonePerf][dynamics] mode=720Hz-real-motion classicBoundary=60Hz")
    }

    let totalStart = diagnosticsEnabled ? ProcessInfo.processInfo.systemUptime : 0
    let inputStart = diagnosticsEnabled ? ProcessInfo.processInfo.systemUptime : 0
    let sampled = input.sample(controller: controllers)
    let inputMS = diagnosticsEnabled ? (ProcessInfo.processInfo.systemUptime - inputStart) * 1000 : 0

    let coreStart = diagnosticsEnabled ? ProcessInfo.processInfo.systemUptime : 0
    let completed = Int(zone_game_advance_master_ticks(game, sampled, UInt32(masterTicks)))
    let coreMS = diagnosticsEnabled ? (ProcessInfo.processInfo.systemUptime - coreStart) * 1000 : 0

    var events = Array(repeating: ZoneAudioEvent(), count: 16)
    let drainStart = diagnosticsEnabled ? ProcessInfo.processInfo.systemUptime : 0
    let n = events.withUnsafeMutableBufferPointer {
      zone_game_drain_audio(game, $0.baseAddress, Int32($0.count))
    }
    let drainMS = diagnosticsEnabled ? (ProcessInfo.processInfo.systemUptime - drainStart) * 1000 : 0

    var audioMS = 0.0
    var audioMaxMS = 0.0
    var audioMaxType: Int32 = 0
    if n > 0 {
      let audioStart = diagnosticsEnabled ? ProcessInfo.processInfo.systemUptime : 0
      for i in 0..<Int(n) {
        let oneStart = diagnosticsEnabled ? ProcessInfo.processInfo.systemUptime : 0
        audio.play(events[i])
        if diagnosticsEnabled {
          let oneMS = (ProcessInfo.processInfo.systemUptime - oneStart) * 1000
          if oneMS > audioMaxMS { audioMaxMS = oneMS; audioMaxType = events[i].type }
        }
      }
      if diagnosticsEnabled { audioMS = (ProcessInfo.processInfo.systemUptime - audioStart) * 1000 }
    }

    let hudStart = diagnosticsEnabled ? ProcessInfo.processInfo.systemUptime : 0
    var hudPublished = 0
    if completed > 0 { hudDivider += completed }
    let currentHUD = zone_game_hud(game)
    let pauseChanged = (currentHUD.paused != 0) != hud.paused
    if hudDivider >= 6 || pauseChanged {
      hudDivider %= 6
      hudPublished = 1
      DispatchQueue.main.async { [weak self] in
        self?.hud = ZoneHUDSnapshot(
          score: Int(currentHUD.score), shields: Int(currentHUD.shields),
          wave: Int(currentHUD.wave), ammo: Int(currentHUD.ammo),
          bases: Int(currentHUD.bases), enemies: Int(currentHUD.enemies),
          speed: currentHUD.speed, maximumSpeed: currentHUD.maximum_speed,
          playerAlive: currentHUD.player_alive != 0, paused: currentHUD.paused != 0)
      }
    }
    let hudMS = diagnosticsEnabled ? (ProcessInfo.processInfo.systemUptime - hudStart) * 1000 : 0

    if diagnosticsEnabled {
      diagnosticsFrame &+= 1
      let totalMS = (ProcessInfo.processInfo.systemUptime - totalStart) * 1000
      if completed > 0 || dynamicsClamped || totalMS > 4.0 {
        print(String(
          format: "[ZonePerf][dynamics] frame=%llu masterTicks=%d classicSteps=%d phase=%u core=%.3f clamped=%d",
          diagnosticsFrame, masterTicks, completed, zone_game_debug_master_phase(game),
          coreMS, dynamicsClamped ? 1 : 0))
      }
      if totalMS > 4.0 {
        var dominant = "input"
        var dominantMS = inputMS
        if coreMS > dominantMS { dominant = "core"; dominantMS = coreMS }
        if drainMS > dominantMS { dominant = "drain"; dominantMS = drainMS }
        if audioMS > dominantMS { dominant = "audio"; dominantMS = audioMS }
        if hudMS > dominantMS { dominant = "hud"; dominantMS = hudMS }
        let world = zone_game_world_object_count(game)
        let shots = zone_game_active_projectiles(game)
        let hostile = zone_game_active_hostile_projectiles(game)
        let tick = zone_game_debug_behavior_tick(game)
        let detail = String(
          format: "[ZonePerf][host-detail] frame=%llu total=%.3f input=%.3f core=%.3f drain=%.3f audio=%.3f audioMax=%.3f audioType=%d hud=%.3f hudPub=%d events=%d dominantMS=%.3f wave=%d bases=%d enemies=%d world=%d shots=%d hostile=%d tick=%u masterTicks=%d classicSteps=%d",
          diagnosticsFrame, totalMS, inputMS, coreMS, drainMS, audioMS,
          audioMaxMS, audioMaxType, hudMS, hudPublished, Int(n), dominantMS,
          currentHUD.wave, currentHUD.bases, currentHUD.enemies, world, shots, hostile, tick,
          masterTicks, completed)
        print(detail + " dominant=\(dominant)")
      }
    }
    return completed
  }

  /// One authoritative Classic game step. Presentation code should call
  /// advance(presentationTime:) instead of calling this directly.
  private func step() {
    if !diagnosticsEnabled {
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
