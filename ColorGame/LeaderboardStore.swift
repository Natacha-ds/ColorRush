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
    
    private let resetKey = "leaderboard.reset.done"
    
    private init() {
        // Reset leaderboard once (clear legacy data)
        if !userDefaults.bool(forKey: resetKey) {
            resetLeaderboard()
            userDefaults.set(true, forKey: resetKey)
        }
        loadScores()
    }
    
    func resetLeaderboard() {
        // Clear all leaderboard data
        userDefaults.removeObject(forKey: easyKey)
        userDefaults.removeObject(forKey: normalKey)
        userDefaults.removeObject(forKey: hardKey)
        easyScores = []
        normalScores = []
        hardScores = []
        userDefaults.synchronize()
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
        return Array(scores.sorted(by: >).prefix(5)) // Keep only top 5
    }
    
    private func saveScores(_ scores: [ScoreEntry], forKey key: String) {
        let sortedScores = Array(scores.sorted(by: >).prefix(5)) // Keep only top 5
        if let data = try? JSONEncoder().encode(sortedScores) {
            userDefaults.set(data, forKey: key)
        }
    }
    
    func addScore(_ score: Int, for mistakeTolerance: MistakeTolerance) {
        let newEntry = ScoreEntry(score: score)
        
        switch mistakeTolerance {
        case .easy:
            easyScores.append(newEntry)
            easyScores = Array(easyScores.sorted(by: >).prefix(5)) // Keep only top 5
            saveScores(easyScores, forKey: easyKey)
        case .normal:
            normalScores.append(newEntry)
            normalScores = Array(normalScores.sorted(by: >).prefix(5)) // Keep only top 5
            saveScores(normalScores, forKey: normalKey)
        case .hard:
            hardScores.append(newEntry)
            hardScores = Array(hardScores.sorted(by: >).prefix(5)) // Keep only top 5
            saveScores(hardScores, forKey: hardKey)
        }
    }
    
    func getScores(for mistakeTolerance: MistakeTolerance) -> [ScoreEntry] {
        switch mistakeTolerance {
        case .easy: return easyScores
        case .normal: return normalScores
        case .hard: return hardScores
        }
    }
    
    func getBestScore(for mistakeTolerance: MistakeTolerance) -> Int {
        let scores = getScores(for: mistakeTolerance)
        return scores.first?.score ?? 0
    }
    
    // Get the overall best score across all difficulty levels
    func getOverallBestScore() -> Int {
        let allScores = easyScores + normalScores + hardScores
        return allScores.max(by: { $0.score < $1.score })?.score ?? 0
    }
}
