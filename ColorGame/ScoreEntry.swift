import Foundation

struct ScoreEntry: Codable, Identifiable {
    let id: UUID
    let score: Int
    let date: Date
    let durationSeconds: Int?
    let maxMistakes: Int?
    let roundTimeoutSeconds: Double?
    let confusionSpeedSeconds: Double?
    
    init(score: Int, date: Date = Date(), durationSeconds: Int? = nil, maxMistakes: Int? = nil, roundTimeoutSeconds: Double? = nil, confusionSpeedSeconds: Double? = nil) {
        self.id = UUID()
        self.score = score
        self.date = date
        self.durationSeconds = durationSeconds
        self.maxMistakes = maxMistakes
        self.roundTimeoutSeconds = roundTimeoutSeconds
        self.confusionSpeedSeconds = confusionSpeedSeconds
    }
}

// Extension to make ScoreEntry comparable for sorting
extension ScoreEntry: Comparable {
    static func < (lhs: ScoreEntry, rhs: ScoreEntry) -> Bool {
        return lhs.score < rhs.score
    }
    
    static func == (lhs: ScoreEntry, rhs: ScoreEntry) -> Bool {
        return lhs.score == rhs.score && lhs.date == rhs.date
    }
}
