import Foundation
import Combine

// MARK: - Game Types
enum GameType: String, CaseIterable, Identifiable {
    case colorOnly = "colorOnly"
    case colorAndText = "colorAndText"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .colorOnly:
            return "🎨 Color Only"
        case .colorAndText:
            return "🎯 Color + Text"
        }
    }
    
    var description: String {
        switch self {
        case .colorOnly:
            return "Match colors only"
        case .colorAndText:
            return "Match colors and text labels"
        }
    }
}

// MARK: - Mistake Tolerance
enum MistakeTolerance: String, CaseIterable, Identifiable {
    case easy = "easy"
    case normal = "normal"
    case hard = "hard"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .easy: return "😊 Easy"
        case .normal: return "😐 Normal"
        case .hard: return "😤 Hard"
        }
    }
    
    var maxMistakes: Int {
        switch self {
        case .easy: return 2
        case .normal: return 1
        case .hard: return 0
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "2 mistakes allowed"
        case .normal: return "1 mistake allowed"
        case .hard: return "No mistakes allowed"
        }
    }
}

// MARK: - Level Configuration
struct LevelConfig: Codable, Identifiable {
    let id: Int
    let durationSeconds: Int
    let timePerResponse: Double? // nil means no limit
    let requiredScore: Int
    let pointsPerRound: Int
    let perfectBonus: Int?
    
    var hasTimeLimit: Bool {
        return timePerResponse != nil
    }
    
    var isNonPunitiveRefresh: Bool {
        return id >= 9 // Levels 9-10 use non-punitive board refresh
    }
}

// MARK: - Level System Configuration
class LevelSystemConfig {
    static let shared = LevelSystemConfig()
    
    private init() {}
    
    // Level configuration table as specified
    let levels: [LevelConfig] = [
        LevelConfig(id: 1, durationSeconds: 30, timePerResponse: nil, requiredScore: 200, pointsPerRound: 10, perfectBonus: nil),
        LevelConfig(id: 2, durationSeconds: 30, timePerResponse: nil, requiredScore: 250, pointsPerRound: 10, perfectBonus: nil),
        LevelConfig(id: 3, durationSeconds: 30, timePerResponse: 1.8, requiredScore: 300, pointsPerRound: 15, perfectBonus: 30),
        LevelConfig(id: 4, durationSeconds: 30, timePerResponse: 1.8, requiredScore: 375, pointsPerRound: 15, perfectBonus: 30),
        LevelConfig(id: 5, durationSeconds: 30, timePerResponse: 1.5, requiredScore: 400, pointsPerRound: 20, perfectBonus: 40),
        LevelConfig(id: 6, durationSeconds: 30, timePerResponse: 1.5, requiredScore: 500, pointsPerRound: 20, perfectBonus: 40),
        LevelConfig(id: 7, durationSeconds: 30, timePerResponse: 1.2, requiredScore: 600, pointsPerRound: 25, perfectBonus: 50),
        LevelConfig(id: 8, durationSeconds: 30, timePerResponse: 1.2, requiredScore: 650, pointsPerRound: 25, perfectBonus: 50),
        LevelConfig(id: 9, durationSeconds: 30, timePerResponse: 1.0, requiredScore: 700, pointsPerRound: 30, perfectBonus: 60),
        LevelConfig(id: 10, durationSeconds: 15, timePerResponse: 1.0, requiredScore: 750, pointsPerRound: 30, perfectBonus: 60)
    ]
    
    func getLevel(_ levelNumber: Int) -> LevelConfig? {
        return levels.first { $0.id == levelNumber }
    }
    
    func getTotalLevels() -> Int {
        return levels.count
    }
}

// MARK: - Level Run State
class LevelRun: ObservableObject {
    @Published var currentLevel: Int = 1
    @Published var gameType: GameType = .colorOnly
    @Published var mistakeTolerance: MistakeTolerance = .easy
    @Published var isActive: Bool = false
    @Published var isCompleted: Bool = false
    
    // Scoring
    @Published var currentScore: Int = 0
    @Published var mistakes: Int = 0
    @Published var timeouts: Int = 0
    @Published var perfectLevels: [Int] = [] // Track which levels were completed perfectly
    
    // Level progression tracking
    @Published var completedLevels: [Int] = []
    @Published var failedLevels: [Int] = []
    @Published var levelScores: [Int: Int] = [:] // Track score for each level
    @Published var globalScore: Int = 0 // Total cumulative score for leaderboard
    
    private let config = LevelSystemConfig.shared
    
    // Dev tools flag - only enabled in DEBUG builds
    #if DEBUG
    private let isDevToolsEnabled = true
    #else
    private let isDevToolsEnabled = false
    #endif
    
    var currentLevelConfig: LevelConfig? {
        return config.getLevel(currentLevel)
    }
    
    var canProceedToNextLevel: Bool {
        guard let levelConfig = currentLevelConfig else { return false }
        return currentScore >= levelConfig.requiredScore
    }
    
    var isPerfectLevel: Bool {
        return mistakes == 0 && timeouts == 0
    }
    
    var shouldShowDevTools: Bool {
        return isDevToolsEnabled
    }
    
    func skipToNextLevel() {
        guard isDevToolsEnabled, let levelConfig = currentLevelConfig else { return }
        
        // Log dev skip for analytics
        print("dev_skip_level: Level \(currentLevel)")
        
        // Award minimum passing score (no perfect bonus)
        currentScore = levelConfig.requiredScore
        globalScore += levelConfig.requiredScore
        
        // Store the level score
        levelScores[currentLevel] = currentScore
        
        // Mark level as completed (not perfect)
        completedLevels.append(currentLevel)
        
        // Check if run is complete
        if currentLevel >= config.getTotalLevels() {
            isCompleted = true
            isActive = false
        } else {
            currentLevel += 1
            startLevel()
        }
    }
    
    func startRun(gameType: GameType, mistakeTolerance: MistakeTolerance) {
        self.gameType = gameType
        self.mistakeTolerance = mistakeTolerance
        self.currentLevel = 1
        self.isActive = true
        self.isCompleted = false
        resetRunStats()
    }
    
    func startLevel() {
        // Reset level-specific stats and score
        mistakes = 0
        timeouts = 0
        currentScore = 0 // Each level starts with 0 points
    }
    
    func completeLevel() {
        guard let levelConfig = currentLevelConfig else { return }
        
        // Store the level score (currentScore is already the level score since we reset it to 0)
        levelScores[currentLevel] = currentScore
        
        completedLevels.append(currentLevel)
        
        if isPerfectLevel {
            perfectLevels.append(currentLevel)
        }
        
        // Check if run is complete
        if currentLevel >= config.getTotalLevels() {
            isCompleted = true
            isActive = false
        } else {
            currentLevel += 1
            startLevel()
        }
    }
    
    func failLevel() {
        failedLevels.append(currentLevel)
        isActive = false
        isCompleted = false
    }
    
    func resetRunStats() {
        currentScore = 0
        globalScore = 0 // Reset global score for new run
        mistakes = 0
        timeouts = 0
        perfectLevels = []
        completedLevels = []
        failedLevels = []
        levelScores = [:] // Clear previous level scores
    }
    
    func resetLevelStats() {
        mistakes = 0
        timeouts = 0
        currentScore = 0 // Reset level score to 0 when retrying
    }
    
    func addCorrectAnswer() {
        guard let levelConfig = currentLevelConfig else { return }
        currentScore += levelConfig.pointsPerRound
        globalScore += levelConfig.pointsPerRound
    }
    
    func addWrongAnswer() {
        currentScore -= 10
        globalScore -= 10
        mistakes += 1
    }
    
    func addTimeout() {
        currentScore -= 5
        globalScore -= 5
        timeouts += 1
    }
    
    func getCurrentLevelScore() -> Int {
        return currentScore // currentScore is already the level score
    }
    
    func getPerfectBonus() -> Int {
        guard let levelConfig = currentLevelConfig,
              let bonus = levelConfig.perfectBonus,
              isPerfectLevel else { return 0 }
        return bonus
    }
}
