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
        case .easy: return 5
        case .normal: return 3
        case .hard: return 0
        }
    }
    
    var description: String {
        switch self {
        case .easy: return "5 mistakes allowed"
        case .normal: return "3 mistakes allowed"
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
        LevelConfig(id: 1, durationSeconds: 30, timePerResponse: nil, requiredScore: 250, pointsPerRound: 10, perfectBonus: nil),
        LevelConfig(id: 2, durationSeconds: 30, timePerResponse: nil, requiredScore: 280, pointsPerRound: 10, perfectBonus: nil),
        LevelConfig(id: 3, durationSeconds: 30, timePerResponse: 1.8, requiredScore: 370, pointsPerRound: 15, perfectBonus: 30),
        LevelConfig(id: 4, durationSeconds: 30, timePerResponse: 1.8, requiredScore: 420, pointsPerRound: 15, perfectBonus: 30),
        LevelConfig(id: 5, durationSeconds: 30, timePerResponse: 1.5, requiredScore: 500, pointsPerRound: 20, perfectBonus: 40),
        LevelConfig(id: 6, durationSeconds: 30, timePerResponse: 1.5, requiredScore: 530, pointsPerRound: 20, perfectBonus: 40),
        LevelConfig(id: 7, durationSeconds: 30, timePerResponse: 1.2, requiredScore: 600, pointsPerRound: 25, perfectBonus: 50),
        LevelConfig(id: 8, durationSeconds: 30, timePerResponse: 1.2, requiredScore: 650, pointsPerRound: 25, perfectBonus: 50),
        LevelConfig(id: 9, durationSeconds: 30, timePerResponse: 1.0, requiredScore: 700, pointsPerRound: 30, perfectBonus: 60),
        LevelConfig(id: 10, durationSeconds: 30, timePerResponse: 1.0, requiredScore: 750, pointsPerRound: 30, perfectBonus: 60)
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
    @Published var currentScore: Int = 0 // Level score (can go negative due to penalties)
    @Published var levelPositivePoints: Int = 0 // Positive points earned this level (to be added to globalScore on completion)
    @Published var levelBasePoints: Int = 0 // Base points from correct answers only (excluding bonuses, for display)
    @Published var levelPenalties: Int = 0 // Penalties from current level attempt (to be removed from globalScore on retry)
    @Published var mistakes: Int = 0 // Run-wide mistakes (cumulative across all levels)
    @Published var timeouts: Int = 0
    @Published var perfectLevels: [Int] = [] // Track which levels were completed perfectly
    
    // Level-specific tracking
    @Published var levelMistakes: Int = 0 // All mistakes (wrong taps + insufficient score)
    @Published var levelMistakesFromWrongTaps: Int = 0 // Only mistakes from wrong taps (with point deductions)
    @Published var levelTimeouts: Int = 0
    @Published var levelCorrectAnswers: Int = 0 // Track correct answers for score breakdown
    
    // Streak tracking for dynamic bonuses
    @Published var currentStreak: Int = 0 // Current consecutive correct answers in this level
    @Published var levelStreakBonuses: Int = 0 // Total streak bonuses earned this level (cumulative)
    @Published var lastBonusEarned: Int = 0 // Last bonus earned (for animation trigger, resets after display)
    
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
    
    // Deprecated: Perfect level check (no longer used for bonuses)
    var isPerfectLevel: Bool {
        return levelMistakes == 0 && levelTimeouts == 0
    }
    
    // Calculate streak bonus for current streak count
    private func calculateStreakBonus(for streak: Int) -> Int {
        if streak >= 30 {
            return 80
        } else if streak >= 20 {
            return 50
        } else if streak >= 10 {
            return 20
        }
        return 0
    }
    
    var shouldShowDevTools: Bool {
        return isDevToolsEnabled
    }
    
    func skipToNextLevel() {
        guard isDevToolsEnabled, let levelConfig = currentLevelConfig else { return }
        
        // Log dev skip for analytics
        print("dev_skip_level: Level \(currentLevel)")
        
        // Award minimum passing score (no perfect bonus)
        // Set both currentScore and levelPositivePoints to required score
        currentScore = levelConfig.requiredScore
        levelPositivePoints = levelConfig.requiredScore
        levelBasePoints = levelConfig.requiredScore // Also set base points for display
        
        // Use completeLevel() to properly add points to globalScore
        completeLevel()
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
        // Reset level-specific stats and score (mistakes remain cumulative)
        levelMistakes = 0
        levelMistakesFromWrongTaps = 0
        levelTimeouts = 0
        levelCorrectAnswers = 0
        currentScore = 0 // Each level starts with 0 points
        levelPositivePoints = 0 // Reset positive points tracker
        levelBasePoints = 0 // Reset base points tracker
        levelPenalties = 0 // Reset penalties tracker
        currentStreak = 0 // Reset streak for new level
        levelStreakBonuses = 0 // Reset streak bonuses for new level
        lastBonusEarned = 0 // Reset bonus animation trigger
    }
    
    func completeLevel() {
        guard let levelConfig = currentLevelConfig else { return }
        
        // Add level's positive points to globalScore only when level completes successfully
        // Note: levelPositivePoints already includes streak bonuses, so we don't add levelStreakBonuses separately
        globalScore += levelPositivePoints
        
        // Store the level score (currentScore is already the level score since we reset it to 0)
        levelScores[currentLevel] = currentScore
        
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
    
    func failLevel() {
        failedLevels.append(currentLevel)
        isActive = false
        isCompleted = false
    }
    
    func resetRunStats() {
        currentScore = 0
        levelPositivePoints = 0
        levelBasePoints = 0
        levelPenalties = 0
        globalScore = 0 // Reset global score for new run
        mistakes = 0 // Reset run-wide mistakes
        timeouts = 0
        levelMistakes = 0
        levelMistakesFromWrongTaps = 0
        levelTimeouts = 0
        levelCorrectAnswers = 0
        currentStreak = 0
        levelStreakBonuses = 0
        lastBonusEarned = 0
        perfectLevels = []
        completedLevels = []
        failedLevels = []
        levelScores = [:] // Clear previous level scores
    }
    
    func resetLevelStats() {
        // Remove penalties from failed attempt from globalScore
        globalScore += levelPenalties // Add back the penalties that were subtracted
        
        levelMistakes = 0
        levelMistakesFromWrongTaps = 0
        levelTimeouts = 0
        levelCorrectAnswers = 0
        currentScore = 0 // Reset level score to 0 when retrying
        levelPositivePoints = 0 // Reset positive points tracker when retrying
        levelBasePoints = 0 // Reset base points tracker when retrying
        levelPenalties = 0 // Reset penalties tracker
        currentStreak = 0 // Reset streak when retrying
        levelStreakBonuses = 0 // Reset streak bonuses when retrying
        lastBonusEarned = 0 // Reset bonus animation trigger
        // Note: mistakes and timeouts are NOT reset here (run-wide)
        // Note: Positive points from failed attempt are discarded (never added to globalScore)
        // Note: Penalties from failed attempt are now removed from globalScore
    }
    
    func addCorrectAnswer() {
        guard let levelConfig = currentLevelConfig else { return }
        
        // Increment streak
        currentStreak += 1
        levelCorrectAnswers += 1 // Track for score breakdown
        
        // Add base points (without bonuses)
        currentScore += levelConfig.pointsPerRound
        levelPositivePoints += levelConfig.pointsPerRound
        levelBasePoints += levelConfig.pointsPerRound // Track base points separately for display
        
        // Check for streak bonus milestones (10, 20, 30)
        // Calculate the total bonus that should be applied at this streak level
        let totalBonusAtThisStreak = calculateStreakBonus(for: currentStreak)
        // Calculate how much bonus we've already added (from previous milestones)
        let bonusAlreadyAdded = levelStreakBonuses
        // Calculate the incremental bonus to add now
        let bonusEarned = totalBonusAtThisStreak - bonusAlreadyAdded
        
        if bonusEarned > 0 {
            // Award streak bonus incrementally (add to levelPositivePoints but NOT to levelBasePoints)
            currentScore += bonusEarned
            levelPositivePoints += bonusEarned
            levelStreakBonuses += bonusEarned
            // Trigger animation by setting lastBonusEarned
            lastBonusEarned = bonusEarned
        }
        
        // Note: globalScore is NOT updated here - only on level completion
    }
    
    func addWrongAnswer() {
        // Reset streak on wrong answer
        currentStreak = 0
        
        // Penalties apply immediately to both currentScore and globalScore
        currentScore -= 10
        globalScore -= 10
        levelPenalties += 10 // Track penalty for potential retry removal
        mistakes += 1 // Run-wide mistake counter
        levelMistakes += 1 // Level-specific mistake counter (all mistakes)
        levelMistakesFromWrongTaps += 1 // Only wrong-tap mistakes (for stat block display)
    }
    
    func addTimeout() {
        // Reset streak on timeout (missed round)
        currentStreak = 0
        
        // Penalties apply immediately to both currentScore and globalScore
        currentScore -= 5
        globalScore -= 5
        levelPenalties += 5 // Track penalty for potential retry removal
        timeouts += 1 // Run-wide timeout counter
        levelTimeouts += 1 // Level-specific timeout counter
    }
    
    func getCurrentLevelScore() -> Int {
        return currentScore // currentScore is already the level score
    }
    
    // Deprecated: Perfect bonus (replaced by streak bonuses)
    func getPerfectBonus() -> Int {
        // No longer used - streak bonuses are awarded during gameplay
        return 0
    }
    
    // Get total streak bonuses earned this level
    func getLevelStreakBonuses() -> Int {
        return levelStreakBonuses
    }
}
