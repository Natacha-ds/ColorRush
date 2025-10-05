import Foundation
import Combine

class LeaderboardStore: ObservableObject {
    static let shared = LeaderboardStore()
    
    private let userDefaults = UserDefaults.standard
    private let easyKey = "leaderboard.easy"
    private let normalKey = "leaderboard.normal"
    private let hardKey = "leaderboard.hard"
    
    @Published var easyScores: [ScoreEntry] = []
    @Published var normalScores: [ScoreEntry] = []
    @Published var hardScores: [ScoreEntry] = []
    
    private init() {
        loadScores()
    }
    
    private func loadScores() {
        easyScores = loadScores(forKey: easyKey)
        normalScores = loadScores(forKey: normalKey)
        hardScores = loadScores(forKey: hardKey)
    }
    
    private func loadScores(forKey key: String) -> [ScoreEntry] {
        guard let data = userDefaults.data(forKey: key),
              let scores = try? JSONDecoder().decode([ScoreEntry].self, from: data) else {
            return []
        }
        return scores.sorted(by: >) // Sort descending
    }
    
    private func saveScores(_ scores: [ScoreEntry], forKey key: String) {
        let sortedScores = scores.sorted(by: >)
        if let data = try? JSONEncoder().encode(sortedScores) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    func addScore(_ score: Int, for difficulty: Difficulty, durationSeconds: Int? = nil, maxMistakes: Int? = nil) {
        let newEntry = ScoreEntry(score: score, durationSeconds: durationSeconds, maxMistakes: maxMistakes)
        
        switch difficulty {
        case .easy:
            easyScores.append(newEntry)
            easyScores = Array(easyScores.sorted(by: >).prefix(10))
            saveScores(easyScores, forKey: easyKey)
        case .normal:
            normalScores.append(newEntry)
            normalScores = Array(normalScores.sorted(by: >).prefix(10))
            saveScores(normalScores, forKey: normalKey)
        case .hard:
            hardScores.append(newEntry)
            hardScores = Array(hardScores.sorted(by: >).prefix(10))
            saveScores(hardScores, forKey: hardKey)
        }
    }
    
    func getScores(for difficulty: Difficulty) -> [ScoreEntry] {
        switch difficulty {
        case .easy: return easyScores
        case .normal: return normalScores
        case .hard: return hardScores
        }
    }
    
    func getBestScore(for difficulty: Difficulty) -> Int {
        let scores = getScores(for: difficulty)
        return scores.first?.score ?? 0
    }
}
