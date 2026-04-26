import Combine
import Foundation

// MARK: - Game Types

enum GameType: String, CaseIterable, Identifiable {
  case colorOnly
  case colorAndText

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .colorOnly:
      "🎨 Color Only"
    case .colorAndText:
      "🎯 Color + Text"
    }
  }

  var description: String {
    switch self {
    case .colorOnly:
      "Match colors only"
    case .colorAndText:
      "Match colors and text labels"
    }
  }
}

// MARK: - Mistake Tolerance (now represents total lives for the run)

enum MistakeTolerance: String, CaseIterable, Identifiable {
  case easy
  case normal
  case hard

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .easy: "😊 Easy"
    case .normal: "😐 Normal"
    case .hard: "😤 Hard"
    }
  }

  var totalLives: Int {
    switch self {
    case .easy: 5
    case .normal: 3
    case .hard: 1
    }
  }

  var description: String {
    switch self {
    case .easy: "5 lives"
    case .normal: "3 lives"
    case .hard: "1 life"
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

  var hasTimeLimit: Bool {
    timePerResponse != nil
  }

  var isNonPunitiveRefresh: Bool {
    id >= 9 // Levels 9-10 use non-punitive board refresh
  }
}

// MARK: - Level System Configuration

class LevelSystemConfig {
  static let shared = LevelSystemConfig()

  private init() {}

  // Level configuration table as specified
  let levels: [LevelConfig] = [
    LevelConfig(
      id: 1,
      durationSeconds: 30,
      timePerResponse: nil,
      requiredScore: 250,
      pointsPerRound: 10
    ),
    LevelConfig(
      id: 2,
      durationSeconds: 30,
      timePerResponse: nil,
      requiredScore: 280,
      pointsPerRound: 10
    ),
    LevelConfig(
      id: 3,
      durationSeconds: 30,
      timePerResponse: 1.8,
      requiredScore: 370,
      pointsPerRound: 15
    ),
    LevelConfig(
      id: 4,
      durationSeconds: 30,
      timePerResponse: 1.8,
      requiredScore: 420,
      pointsPerRound: 15
    ),
    LevelConfig(
      id: 5,
      durationSeconds: 30,
      timePerResponse: 1.5,
      requiredScore: 500,
      pointsPerRound: 20
    ),
    LevelConfig(
      id: 6,
      durationSeconds: 30,
      timePerResponse: 1.5,
      requiredScore: 530,
      pointsPerRound: 20
    ),
    LevelConfig(
      id: 7,
      durationSeconds: 30,
      timePerResponse: 1.2,
      requiredScore: 600,
      pointsPerRound: 25
    ),
    LevelConfig(
      id: 8,
      durationSeconds: 30,
      timePerResponse: 1.2,
      requiredScore: 650,
      pointsPerRound: 25
    ),
    LevelConfig(
      id: 9,
      durationSeconds: 30,
      timePerResponse: 1.0,
      requiredScore: 700,
      pointsPerRound: 30
    ),
    LevelConfig(
      id: 10,
      durationSeconds: 30,
      timePerResponse: 1.0,
      requiredScore: 750,
      pointsPerRound: 30
    ),
  ]

  func getLevel(_ levelNumber: Int) -> LevelConfig? {
    levels.first { $0.id == levelNumber }
  }

  func getTotalLevels() -> Int {
    levels.count
  }

  // Get required score for a level based on game type
  func getRequiredScore(for levelNumber: Int, gameType: GameType) -> Int {
    guard let levelConfig = getLevel(levelNumber) else {
      return 0
    }

    // For Color + Text mode, use different required scores
    if gameType == .colorAndText {
      switch levelNumber {
      case 1: return 260
      case 2: return 300
      case 3: return 350
      case 4: return 390
      case 5: return 430
      case 6: return 470
      case 7: return 550
      case 8: return 600
      case 9: return 630
      case 10: return 680
      default: return levelConfig.requiredScore
      }
    }

    // For Color Only mode, use the default required score
    return levelConfig.requiredScore
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
  @Published var currentScore: Int =
    0 // Level score (can go negative due to penalties)
  @Published var levelPositivePoints: Int =
    0 // Positive points earned this level (to be added to globalScore on
  // completion)
  @Published var levelBasePoints: Int =
    0 // Base points from correct answers only (excluding bonuses, for display)
  @Published var levelPenalties: Int =
    0 // Penalties from current level attempt (to be removed from globalScore on
  // retry)
  @Published var livesLost: Int =
    0 // Lives lost during the run (only when failing a level)
  @Published var timeouts: Int = 0

  // Level-specific tracking
  @Published var levelWrongTaps: Int =
    0 // Wrong taps (only for display/statistics, no life cost)
  @Published var levelTimeouts: Int = 0
  @Published var levelCorrectAnswers: Int =
    0 // Track correct answers for score breakdown

  // Streak tracking for dynamic bonuses
  @Published var currentStreak: Int =
    0 // Current consecutive correct answers in this level
  @Published var levelStreakBonuses: Int =
    0 // Total streak bonuses earned this level (cumulative)
  @Published var lastBonusEarned: Int =
    0 // Last bonus earned (for animation trigger, resets after display)

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
    config.getLevel(currentLevel)
  }

  var canProceedToNextLevel: Bool {
    guard let levelConfig = currentLevelConfig else { return false }
    let requiredScore = config.getRequiredScore(
      for: currentLevel,
      gameType: gameType
    )
    return currentScore >= requiredScore
  }

  // Get required score for current level based on game type
  func getRequiredScore() -> Int {
    config.getRequiredScore(for: currentLevel, gameType: gameType)
  }

  // Calculate streak bonus for current streak count
  private func calculateStreakBonus(for streak: Int) -> Int {
    if gameType == .colorAndText {
      // Color + Text mode: +10 points every 5 consecutive correct answers
      // At 5, 10, 15, 20, 25, 30, etc.
      let bonusCount = streak / 5
      return bonusCount * 10
    } else {
      // Color Only mode: original system (10→+20, 20→+50, 30→+80)
      if streak >= 30 {
        return 80
      } else if streak >= 20 {
        return 50
      } else if streak >= 10 {
        return 20
      }
      return 0
    }
  }

  var shouldShowDevTools: Bool {
    isDevToolsEnabled
  }

  func skipToNextLevel() {
    guard isDevToolsEnabled,
          let levelConfig = currentLevelConfig else { return }

    // Log dev skip for analytics
    print("dev_skip_level: Level \(currentLevel)")

    // Award minimum passing score (no perfect bonus)
    // Set both currentScore and levelPositivePoints to required score
    let requiredScore = config.getRequiredScore(
      for: currentLevel,
      gameType: gameType
    )
    currentScore = requiredScore
    levelPositivePoints = requiredScore
    levelBasePoints = requiredScore // Also set base points for display

    // Use completeLevel() to properly add points to globalScore
    completeLevel()
  }

  func startRun(gameType: GameType, mistakeTolerance: MistakeTolerance) {
    self.gameType = gameType
    self.mistakeTolerance = mistakeTolerance
    currentLevel = 1
    isActive = true
    isCompleted = false
    resetRunStats()
  }

  func startLevel() {
    // Reset level-specific stats and score (lives remain cumulative)
    levelWrongTaps = 0
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

    // Add level's positive points to globalScore only when level completes
    // successfully
    // Note: levelPositivePoints already includes streak bonuses, so we don't
    // add levelStreakBonuses separately
    globalScore += levelPositivePoints

    // Store the level score (currentScore is already the level score since we
    // reset it to 0)
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
    livesLost = 0 // Reset lives lost for new run
    timeouts = 0
    levelWrongTaps = 0
    levelTimeouts = 0
    levelCorrectAnswers = 0
    currentStreak = 0
    levelStreakBonuses = 0
    lastBonusEarned = 0
    completedLevels = []
    failedLevels = []
    levelScores = [:] // Clear previous level scores
  }

  func resetLevelStats() {
    // Remove penalties from failed attempt from globalScore
    globalScore += levelPenalties // Add back the penalties that were subtracted

    levelWrongTaps = 0
    levelTimeouts = 0
    levelCorrectAnswers = 0
    currentScore = 0 // Reset level score to 0 when retrying
    levelPositivePoints = 0 // Reset positive points tracker when retrying
    levelBasePoints = 0 // Reset base points tracker when retrying
    levelPenalties = 0 // Reset penalties tracker
    currentStreak = 0 // Reset streak when retrying
    levelStreakBonuses = 0 // Reset streak bonuses when retrying
    lastBonusEarned = 0 // Reset bonus animation trigger
    // Note: livesLost is NOT reset here (run-wide)
    // Note: Positive points from failed attempt are discarded (never added to
    // globalScore)
    // Note: Penalties from failed attempt are now removed from globalScore
  }

  func addCorrectAnswer() {
    guard let levelConfig = currentLevelConfig else { return }

    // Increment streak
    currentStreak += 1
    levelCorrectAnswers += 1 // Track for score breakdown

    // Get points based on game type and level
    let pointsToAdd = getPointsPerRound(for: levelConfig)

    // Add base points (without bonuses)
    currentScore += pointsToAdd
    levelPositivePoints += pointsToAdd
    levelBasePoints += pointsToAdd // Track base points separately for display

    // Check for streak bonus milestones
    // Color Only: 10→+20, 20→+50, 30→+80
    // Color + Text: +10 every 5 consecutive (5, 10, 15, 20, 25, 30, etc.)
    // Calculate the total bonus that should be applied at this streak level
    let totalBonusAtThisStreak = calculateStreakBonus(for: currentStreak)
    // Calculate how much bonus we've already added (from previous milestones)
    let bonusAlreadyAdded = levelStreakBonuses
    // Calculate the incremental bonus to add now
    let bonusEarned = totalBonusAtThisStreak - bonusAlreadyAdded

    if bonusEarned > 0 {
      // Award streak bonus incrementally (add to levelPositivePoints but NOT to
      // levelBasePoints)
      currentScore += bonusEarned
      levelPositivePoints += bonusEarned
      levelStreakBonuses += bonusEarned
      // Trigger animation by setting lastBonusEarned
      lastBonusEarned = bonusEarned
    }

    // Note: globalScore is NOT updated here - only on level completion
  }

  func addWrongAnswer() {
    currentStreak = 0

    // Wrong answer costs points (not lives). Scores floor at 0; track only the
    // amount actually subtracted from globalScore so retry refunds stay correct.
    currentScore = max(0, currentScore - 10)
    let oldGlobal = globalScore
    globalScore = max(0, globalScore - 10)
    levelPenalties += oldGlobal - globalScore

    levelWrongTaps += 1
  }

  func addTimeout() {
    currentStreak = 0

    // Timeout costs points (not lives). Same clamping/refund-tracking pattern
    // as addWrongAnswer.
    currentScore = max(0, currentScore - 5)
    let oldGlobal = globalScore
    globalScore = max(0, globalScore - 5)
    levelPenalties += oldGlobal - globalScore

    timeouts += 1
    levelTimeouts += 1
  }

  // Lose a life when failing a level (not reaching required score)
  func loseLife() {
    livesLost += 1
  }

  // Get remaining lives
  var remainingLives: Int {
    max(0, mistakeTolerance.totalLives - livesLost)
  }

  // Check if game over (no lives remaining)
  var isGameOver: Bool {
    remainingLives <= 0
  }

  func getCurrentLevelScore() -> Int {
    currentScore // currentScore is already the level score
  }

  // Get total streak bonuses earned this level
  func getLevelStreakBonuses() -> Int {
    levelStreakBonuses
  }

  // Get points per round based on game type and level
  private func getPointsPerRound(for levelConfig: LevelConfig) -> Int {
    // For Color Only mode, use the standard points from config
    if gameType == .colorOnly {
      return levelConfig.pointsPerRound
    }

    // For Color + Text mode, use different points based on level
    switch levelConfig.id {
    case 1, 2:
      return 15 // Instead of 10
    case 3, 4:
      return 20 // Instead of 15
    case 5, 6:
      return 25 // Instead of 20
    case 7, 8:
      return 30 // Instead of 25
    case 9, 10:
      return 35 // Instead of 30
    default:
      return levelConfig.pointsPerRound // Fallback to standard points
    }
  }
}
