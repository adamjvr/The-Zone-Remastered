import AVFoundation
import Foundation

final class ZoneAudioEngine {
  private struct VoiceBank {
    var voices: [AVAudioPlayer]
    var nextVoice = 0
  }

  // This is deliberately a capacity choice, not a claim about the exact
  // Classic Sound Manager channel count. It guarantees that a burst of the
  // same mapped sample does not destroy the previous AVAudioPlayer instance.
  private static let voicesPerSound = 16
  private var banks: [Int: VoiceBank] = [:]
  private let diagnosticsEnabled = ProcessInfo.processInfo.environment["ZONE_PERF_DIAGNOSTICS"] == "1"
  private var voiceStealCount = 0

  // Initial engineering mappings. The complete 36-sound original library is
  // bundled; exact event->resource mapping will be replaced as 0x1487C/0x1B8F0 is fully lifted.
  private let soundForEvent: [Int32: Int] = [
    1: 153,
    2: 130,
    3: 131,
    // Original PPC nonlethal Mother/HQ path requests sound-effect index 8.
    // Exact legacy index->snd resource mapping is still pending; use the
    // current generic impact sample so a valid hit is never silent.
    4: 131,
  ]

  init() {
    preloadMappedSounds()
  }

  private func preloadMappedSounds() {
    for sid in Set(soundForEvent.values) {
      guard
        let url = Bundle.main.url(
          forResource: "snd_\(sid)", withExtension: "wav", subdirectory: "Sounds"),
        let data = try? Data(contentsOf: url)
      else {
        if diagnosticsEnabled { print("[ZonePerf][audio] missing mapped sound sid=\(sid)") }
        continue
      }

      var voices: [AVAudioPlayer] = []
      voices.reserveCapacity(Self.voicesPerSound)
      for _ in 0..<Self.voicesPerSound {
        guard let player = try? AVAudioPlayer(data: data) else { continue }
        player.volume = 0.75
        player.prepareToPlay()
        voices.append(player)
      }
      if !voices.isEmpty {
        banks[sid] = VoiceBank(voices: voices)
      }
      if diagnosticsEnabled {
        print("[ZonePerf][audio] sid=\(sid) preparedVoices=\(voices.count)")
      }
    }
  }

  func play(_ event: ZoneAudioEvent) {
    guard let sid = soundForEvent[event.type], var bank = banks[sid], !bank.voices.isEmpty else {
      return
    }

    let voiceIndex: Int
    if let free = bank.voices.firstIndex(where: { !$0.isPlaying }) {
      voiceIndex = free
    } else {
      voiceIndex = bank.nextVoice % bank.voices.count
      voiceStealCount += 1
      if diagnosticsEnabled {
        print("[ZonePerf][audio] voice-steal sid=\(sid) total=\(voiceStealCount)")
      }
      bank.voices[voiceIndex].stop()
    }

    let player = bank.voices[voiceIndex]
    player.currentTime = 0
    player.play()
    bank.nextVoice = (voiceIndex + 1) % bank.voices.count
    banks[sid] = bank
  }
}
