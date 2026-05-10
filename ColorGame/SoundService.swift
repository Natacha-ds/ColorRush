import AVFoundation

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
    switch click {
    case .main:
      playFromPool(&mainPlayers, index: &mainIndex)
    case .secondary:
      playFromPool(&secondaryPlayers, index: &secondaryIndex)
    }
  }

  private func playFromPool(_ pool: inout [AVAudioPlayer], index: inout Int) {
    guard !pool.isEmpty else { return }
    let player = pool[index]
    index = (index + 1) % pool.count
    player.currentTime = 0
    player.play()
  }

  /// Click sounds master gain. The raw mp3s are mastered loud — we mix them
  /// down so they sit a quarter as loud as the spoken-color voice prompts
  /// (which play at full volume through SpeechService).
  private static let clickVolume: Float = 0.25

  private static func makePool(resource: String, count: Int) -> [AVAudioPlayer] {
    guard let url = Bundle.main.url(forResource: resource, withExtension: "mp3") else {
      return []
    }
    return (0..<count).compactMap { _ in
      let player = try? AVAudioPlayer(contentsOf: url)
      player?.volume = clickVolume
      player?.prepareToPlay()
      return player
    }
  }
}
