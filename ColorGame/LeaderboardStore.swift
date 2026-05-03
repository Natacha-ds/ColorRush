import Combine
import Foundation

struct LeaderboardKey: Hashable {
  let gameType: GameType
  let mistakeTolerance: MistakeTolerance

  var storageKey: String {
    "leaderboard.\(gameType.rawValue).\(mistakeTolerance.rawValue)"
  }
}

class LeaderboardStore: ObservableObject {
  static let shared = LeaderboardStore()

  private let userDefaults = UserDefaults.standard

  // Legacy v1 keys (MistakeTolerance only). Removed during the v2 migration.
  private let legacyEasyKey = "leaderboard.easy"
  private let legacyNormalKey = "leaderboard.normal"
  private let legacyHardKey = "leaderboard.hard"

  @Published var scoresByKey: [LeaderboardKey: [ScoreEntry]] = [:]

  private let resetKey = "leaderboard.reset.done.v2"

  private init() {
    if !userDefaults.bool(forKey: resetKey) {
      resetLeaderboard()
      userDefaults.set(true, forKey: resetKey)
    }
    loadScores()
  }

  func resetLeaderboard() {
    // Clear all current-schema keys.
    for gameType in GameType.allCases {
      for tolerance in MistakeTolerance.allCases {
        let key = LeaderboardKey(
          gameType: gameType,
          mistakeTolerance: tolerance
        )
        userDefaults.removeObject(forKey: key.storageKey)
      }
    }
    // Clear legacy v1 keys so they don't linger in UserDefaults.
    userDefaults.removeObject(forKey: legacyEasyKey)
    userDefaults.removeObject(forKey: legacyNormalKey)
    userDefaults.removeObject(forKey: legacyHardKey)
    scoresByKey = [:]
    userDefaults.synchronize()
  }

  private func loadScores() {
    var loaded: [LeaderboardKey: [ScoreEntry]] = [:]
    for gameType in GameType.allCases {
      for tolerance in MistakeTolerance.allCases {
        let key = LeaderboardKey(
          gameType: gameType,
          mistakeTolerance: tolerance
        )
        loaded[key] = loadScores(forKey: key.storageKey)
      }
    }
    scoresByKey = loaded
  }

  private func loadScores(forKey key: String) -> [ScoreEntry] {
    guard let data = userDefaults.data(forKey: key) else { return [] }
    do {
      let scores = try JSONDecoder().decode([ScoreEntry].self, from: data)
      return Array(scores.sorted(by: >).prefix(5)) // Keep only top 5
    } catch {
      print("Leaderboard decode failed for key '\(key)': \(error)")
      return []
    }
  }

  private func saveScores(_ scores: [ScoreEntry], forKey key: String) {
    let sortedScores = Array(scores.sorted(by: >).prefix(5)) // Keep only top 5
    if let data = try? JSONEncoder().encode(sortedScores) {
      userDefaults.set(data, forKey: key)
    }
  }

  func addScore(
    _ score: Int,
    gameType: GameType,
    mistakeTolerance: MistakeTolerance
  ) {
    let key = LeaderboardKey(
      gameType: gameType,
      mistakeTolerance: mistakeTolerance
    )
    var current = scoresByKey[key] ?? []
    current.append(ScoreEntry(score: score))
    current = Array(current.sorted(by: >).prefix(5)) // Keep only top 5
    scoresByKey[key] = current
    saveScores(current, forKey: key.storageKey)
  }

  func getScores(
    gameType: GameType,
    mistakeTolerance: MistakeTolerance
  ) -> [ScoreEntry] {
    let key = LeaderboardKey(
      gameType: gameType,
      mistakeTolerance: mistakeTolerance
    )
    return scoresByKey[key] ?? []
  }

  // Get the overall best score across all (gameType, mistakeTolerance) buckets.
  func getOverallBestScore() -> Int {
    scoresByKey.values
      .flatMap { $0 }
      .max(by: { $0.score < $1.score })?.score ?? 0
  }
}
