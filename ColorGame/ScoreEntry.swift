import Foundation

struct ScoreEntry: Codable, Identifiable {
    let id: UUID
    let score: Int
    let date: Date
    let durationSeconds: Int?
    let maxMistakes: Int?
    
    init(score: Int, date: Date = Date(), durationSeconds: Int? = nil, maxMistakes: Int? = nil) {
        self.id = UUID()
        self.score = score
        self.date = date
        self.durationSeconds = durationSeconds
        self.maxMistakes = maxMistakes
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
