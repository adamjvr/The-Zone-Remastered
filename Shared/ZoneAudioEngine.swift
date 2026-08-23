import AVFoundation
import Foundation

final class ZoneAudioEngine {
  private final class Voice {
    let player: AVAudioPlayerNode
    var busyUntil: TimeInterval = 0

    init(player: AVAudioPlayerNode) {
      self.player = player
    }
  }

  private final class VoiceBank {
    let buffer: AVAudioPCMBuffer
    let duration: TimeInterval
    let voices: [Voice]
    var nextVoice = 0

    init(buffer: AVAudioPCMBuffer, duration: TimeInterval, voices: [Voice]) {
      self.buffer = buffer
      self.duration = duration
      self.voices = voices
    }
  }

  // Capacity choice retained from Milestone 1.1. The accepted perf runs never
  // exhausted sixteen same-sample voices; keeping the same capacity isolates
  // this milestone to the playback backend rather than changing overlap rules.
  private static let voicesPerSound = 16

  private let engine = AVAudioEngine()
  private var banks: [Int: VoiceBank] = [:]
  private var engineStarted = false
  private let diagnosticsEnabled = ProcessInfo.processInfo.environment["ZONE_PERF_DIAGNOSTICS"] == "1"
  private var voiceStealCount = 0

  // Initial engineering mappings. The complete 36-sound original library is
  // bundled; exact event->resource mapping remains separate reverse-engineering
  // work. Milestone 1.4.2 changes only how the already-selected sample is played.
  private let soundForEvent: [Int32: Int] = [
    1: 153,
    2: 130,
    3: 131,
    // Original PPC nonlethal Mother/HQ path requests sound-effect index 8.
    // Exact legacy index->snd resource mapping is still pending.
    4: 131,
  ]

  init() {
    buildGraphAndPreloadMappedSounds()
  }

  deinit {
    for bank in banks.values {
      for voice in bank.voices { voice.player.stop() }
    }
    engine.stop()
  }

  private func loadBuffer(sid: Int) -> AVAudioPCMBuffer? {
    guard let url = Bundle.main.url(
      forResource: "snd_\(sid)", withExtension: "wav", subdirectory: "Sounds")
    else {
      if diagnosticsEnabled { print("[ZonePerf][audio] missing mapped sound sid=\(sid)") }
      return nil
    }

    do {
      let file = try AVAudioFile(forReading: url)
      guard
        file.length > 0,
        file.length <= AVAudioFramePosition(UInt32.max),
        let buffer = AVAudioPCMBuffer(
          pcmFormat: file.processingFormat,
          frameCapacity: AVAudioFrameCount(file.length))
      else {
        if diagnosticsEnabled { print("[ZonePerf][audio] invalid mapped sound sid=\(sid)") }
        return nil
      }
      try file.read(into: buffer)
      return buffer
    } catch {
      if diagnosticsEnabled {
        print("[ZonePerf][audio] preload-failed sid=\(sid) error=\(error.localizedDescription)")
      }
      return nil
    }
  }

  private func buildGraphAndPreloadMappedSounds() {
    let mixer = engine.mainMixerNode

    for sid in Set(soundForEvent.values).sorted() {
      guard let buffer = loadBuffer(sid: sid) else { continue }
      let sampleRate = buffer.format.sampleRate
      guard sampleRate > 0 else { continue }

      var voices: [Voice] = []
      voices.reserveCapacity(Self.voicesPerSound)
      for _ in 0..<Self.voicesPerSound {
        let player = AVAudioPlayerNode()
        player.volume = 0.75
        engine.attach(player)
        engine.connect(player, to: mixer, format: buffer.format)
        voices.append(Voice(player: player))
      }

      let duration = Double(buffer.frameLength) / sampleRate
      banks[sid] = VoiceBank(buffer: buffer, duration: duration, voices: voices)

      if diagnosticsEnabled {
        print(String(
          format: "[ZonePerf][audio] sid=%d preparedVoices=%d frames=%u rate=%.1f duration=%.4f backend=AVAudioEngine",
          sid, voices.count, buffer.frameLength, sampleRate, duration
        ))
      }
    }

    guard !banks.isEmpty else {
      if diagnosticsEnabled { print("[ZonePerf][audio] engine-start skipped: no mapped buffers") }
      return
    }

    engine.prepare()
    do {
      try engine.start()
      // Start every player once. With a running player node, a later nil-time
      // scheduleBuffer begins in the very near future; gameplay never calls
      // play()/stop()/currentTime on an audio voice.
      for bank in banks.values {
        for voice in bank.voices { voice.player.play() }
      }
      engineStarted = true
      if diagnosticsEnabled {
        let totalVoices = banks.values.reduce(0) { $0 + $1.voices.count }
        print("[ZonePerf][audio] engine-started banks=\(banks.count) voices=\(totalVoices)")
      }
    } catch {
      if diagnosticsEnabled {
        print("[ZonePerf][audio] engine-start-failed error=\(error.localizedDescription)")
      }
    }
  }

  func play(_ event: ZoneAudioEvent) {
    guard
      engineStarted,
      let sid = soundForEvent[event.type],
      let bank = banks[sid],
      !bank.voices.isEmpty
    else { return }

    let now = ProcessInfo.processInfo.systemUptime
    let count = bank.voices.count
    var voiceIndex: Int?

    // Start the search at the rotating cursor so a burst distributes naturally
    // across nodes while still preferring a voice whose previous buffer should
    // have completed. busyUntil is presentation bookkeeping only; it cannot
    // affect ZoneCore state or RNG ordering.
    for offset in 0..<count {
      let candidate = (bank.nextVoice + offset) % count
      if bank.voices[candidate].busyUntil <= now {
        voiceIndex = candidate
        break
      }
    }

    if voiceIndex == nil {
      voiceIndex = bank.nextVoice % count
      voiceStealCount += 1
      if diagnosticsEnabled {
        print("[ZonePerf][audio] voice-steal sid=\(sid) total=\(voiceStealCount)")
      }
    }

    guard let selected = voiceIndex else { return }
    let voice = bank.voices[selected]

    let triggerStart = diagnosticsEnabled ? ProcessInfo.processInfo.systemUptime : 0
    // .interrupts is effectively a no-op for a free voice. If all sixteen are
    // genuinely occupied, it makes the bounded rotating steal explicit instead
    // of allowing an unbounded command queue on one node.
    voice.player.scheduleBuffer(bank.buffer, at: nil, options: .interrupts)
    voice.busyUntil = now + bank.duration
    bank.nextVoice = (selected + 1) % count

    if diagnosticsEnabled {
      let totalMS = (ProcessInfo.processInfo.systemUptime - triggerStart) * 1000
      if totalMS > 2.0 {
        print(String(
          format: "[ZonePerf][audio] slow-trigger sid=%d event=%d voice=%d total=%.3f schedule=%.3f backend=AVAudioEngine",
          sid, event.type, selected, totalMS, totalMS
        ))
      }
    }
  }
}
