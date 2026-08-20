import AVFoundation

final class ZoneAudioEngine {
  private var players: [Int: AVAudioPlayer] = [:]
  // Initial engineering mappings. The complete 36-sound original library is
  // bundled; exact event->resource mapping will be replaced as 0x1487C/0x1B8F0 is fully lifted.
  private let soundForEvent: [Int32: Int] = [
    1: 153,
    2: 130,
    3: 131,
  ]
  func play(_ event: ZoneAudioEvent) {
    guard let sid = soundForEvent[event.type],
      let url = Bundle.main.url(
        forResource: "snd_\(sid)", withExtension: "wav", subdirectory: "Sounds")
    else { return }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.volume = 0.75
      player.prepareToPlay()
      player.play()
      players[sid] = player
    } catch { /* audio failure must never stop the deterministic game loop */  }
  }
}
