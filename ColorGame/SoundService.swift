import AVFoundation
import Foundation

/// Plays short UI click sounds. Two voices: `.main` for primary CTAs
/// (Play / Continue / Try Again / Start Over), `.secondary` for selection
/// taps (mode cards, difficulty chips, tab bar, back / icon buttons).
/// Game-tile taps go through their own audio path and bypass this service.
final class SoundService {
  static let shared = SoundService()

  enum Click {
    case main
    case secondary
  }

  private var mainPlayers: [AVAudioPlayer] = []
  private var secondaryPlayers: [AVAudioPlayer] = []
  private var mainIndex = 0
  private var secondaryIndex = 0

  private init() {
    mainPlayers = Self.makePool(resource: "click-main", count: 4)
    secondaryPlayers = Self.makePool(resource: "click-secondary", count: 4)
  }

  func play(_ click: Click) {
    let scaled = Self.clickVolume * Float(Self.currentAppVolume())
    switch click {
    case .main:
      playFromPool(&mainPlayers, index: &mainIndex, volume: scaled)
    case .secondary:
      playFromPool(&secondaryPlayers, index: &secondaryIndex, volume: scaled)
    }
  }

  private func playFromPool(
    _ pool: inout [AVAudioPlayer],
    index: inout Int,
    volume: Float
  ) {
    guard !pool.isEmpty else { return }
    let player = pool[index]
    index = (index + 1) % pool.count
    player.volume = volume
    player.currentTime = 0
    player.play()
  }

  /// Click sounds master gain. The raw mp3s are mastered loud — we mix them
  /// down so they sit a quarter as loud as the spoken-color voice prompts
  /// (which play at full volume through SpeechService).
  private static let clickVolume: Float = 0.25

  /// Reads the user's settings-sheet volume slider (0.0–1.0). Defaults to 1.0
  /// when the key has never been written. Read at every play so a slider
  /// adjustment takes effect immediately.
  private static func currentAppVolume() -> Double {
    UserDefaults.standard.object(forKey: "cr.appVolume") as? Double ?? 1.0
  }

  private static func makePool(resource: String, count: Int) -> [AVAudioPlayer] {
    guard let url = Bundle.main.url(forResource: resource, withExtension: "mp3") else {
      return []
    }
    return (0 ..< count).compactMap { _ in
      let player = try? AVAudioPlayer(contentsOf: url)
      player?.prepareToPlay()
      return player
    }
  }
}
