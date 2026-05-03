import SwiftUI
#if canImport(UIKit)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

enum LevelFailureReason {
  case maxMistakes
  case insufficientScore
}

struct LevelGameView: View {
  @ObservedObject var levelRun: LevelRun
  @Environment(\.dismiss) private var dismiss
  @State private var showFinalWinView = false

  // Game state
  @State private var announcedColor: Color = .red
  @State private var tiles: [Color] = [] // For Color Only mode
  @State private var tilesWithText: [Tile] = [] // For Color + Text mode
  @State private var previousTiles: [Color] = []
  @State private var previousTilesWithText: [Tile] = []
  @State private var showingErrorFlash = false
  @State private var isGameActive = false

  // Level timer state
  @State private var timeRemaining: Double = 30.0
  @State private var gameTimer: Timer?
  @State private var isGameSessionActive = false
  @State private var backgroundTime: Date?

  // Round timer state (for levels with time limits)
  @State private var roundTimeRemaining: Double = 0
  @State private var roundTimer: Timer?
  @State private var isRoundTimerActive = false

  // Pending deferred work — superseded on re-schedule, cancelled in endGameSession()
  @State private var pendingNextRound: DispatchWorkItem?
  @State private var pendingIntroDismiss: DispatchWorkItem?
  @State private var pendingActivation: DispatchWorkItem?

  // Game over state
  @State private var isLevelComplete = false
  @State private var isLevelFailed = false
  @State private var failedReason: LevelFailureReason = .insufficientScore

  // Streak animation state
  @State private var showStreakAnimation = false
  @State private var streakDisplayCount = 0

  // Level intro pop-in state
  @State private var showLevelIntro = false

  // Color repeat tracking
  @State private var recentAnnouncedColors: [Color] = []

  // Tile position tracking (prevent same position being correct more than 4
  // times in a row)
  // Key: tile position index (0-3), Value: consecutive times this position was correct
  @State private var consecutiveCorrectByPosition: [Int: Int] = [:]

  // Services
  @State private var speechService = SpeechService()
  private let hapticsService = HapticsService.shared

  // Color palette
  private let colorPalette: [Color] = [.red, .blue, .green, .yellow]

  var body: some View {
    NavigationView {
      ZStack {
        // Full screen background - use level-specific image for each level
        Image("Level\(levelRun.currentLevel)")
          .resizable()
          .scaledToFill()
          .ignoresSafeArea(.all)

        if isLevelComplete {
          // Check if this is the final level (10) - show special win screen
          if levelRun.currentLevel == 10 {
            FinalWinView(
              levelRun: levelRun,
              onPlayHarder: {
                // Complete the level and save score
                levelRun.completeLevel()
                LeaderboardStore.shared.addScore(
                  levelRun.globalScore,
                  gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                )
                // Reset everything
                levelRun.resetRunStats()
                levelRun.currentLevel = 1
                levelRun.isActive = false
                // Dismiss to go back to selection funnel
                // (LevelSystemSelectionView)
                dismiss()
              },
              onSeeLeaderboard: {
                // Complete the level and save score
                levelRun.completeLevel()
                LeaderboardStore.shared.addScore(
                  levelRun.globalScore,
                  gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                )
                // Reset everything
                levelRun.resetRunStats()
                levelRun.currentLevel = 1
                levelRun.isActive = false
                // Dismiss LevelGameView first
                dismiss()
                // Then post notification to dismiss LevelSystemSelectionView
                // and switch to leaderboard
                // Use a small delay to ensure the first dismiss completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                  NotificationCenter.default.post(
                    name: NSNotification.Name("SwitchToLeaderboard"),
                    object: nil
                  )
                }
              }
            )
          } else {
            LevelCompleteView(
              levelRun: levelRun,
              onNextLevel: {
                levelRun.completeLevel()
                if levelRun.isCompleted {
                  // Save score to leaderboard when run completes
                  LeaderboardStore.shared.addScore(
                    levelRun.globalScore,
                    gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                  )
                  // Show run complete screen
                  dismiss()
                } else {
                  startNewLevel()
                }
              },
              onBackToHome: {
                let totalScore = levelRun.globalScore + levelRun
                  .levelPositivePoints
                if totalScore > 0 {
                  LeaderboardStore.shared.addScore(
                    totalScore,
                    gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                  )
                }
                levelRun.resetRunStats()
                levelRun.currentLevel = 1
                levelRun.isActive = false
                NotificationCenter.default.post(
                  name: NSNotification.Name("DismissToHome"),
                  object: nil
                )
              }
            )
          }
        } else if isLevelFailed {
          // Show LevelGameOverView for run-ending failures, LevelFailedView for
          // insufficient score
          if failedReason == .maxMistakes {
            LevelGameOverView(
              levelRun: levelRun,
              failedReason: failedReason,
              onBackToHome: {
                // Save score to leaderboard if positive when run ends (game
                // over)
                let totalScore = levelRun.globalScore + levelRun
                  .levelPositivePoints
                if totalScore > 0 {
                  LeaderboardStore.shared.addScore(
                    totalScore,
                    gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                  )
                }
                // Reset everything when going back to home after game over
                levelRun.resetRunStats()
                levelRun.currentLevel = 1
                levelRun.isActive = false
                NotificationCenter.default.post(
                  name: NSNotification.Name("DismissToHome"),
                  object: nil
                )
              }
            )
          } else {
            LevelFailedView(
              levelRun: levelRun,
              failedReason: failedReason,
              onRetry: {
                startNewLevel()
              },
              onBackToHome: {
                // Save score to leaderboard if positive when run ends
                let totalScore = levelRun.globalScore + levelRun
                  .levelPositivePoints
                if totalScore > 0 {
                  LeaderboardStore.shared.addScore(
                    totalScore,
                    gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                  )
                }
                levelRun.resetRunStats()
                levelRun.currentLevel = 1
                levelRun.isActive = false
                NotificationCenter.default.post(
                  name: NSNotification.Name("DismissToHome"),
                  object: nil
                )
              }
            )
          }
        } else {
          // Active Game Screen
          ZStack {
            VStack(spacing: 0) {
              // Top header with back button
              HStack {
                Button(action: {
                  endGameSession()
                  let totalScore = levelRun.globalScore + levelRun
                    .levelPositivePoints
                  if totalScore > 0 {
                    LeaderboardStore.shared.addScore(
                      totalScore,
                      gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                    )
                  }
                  levelRun.resetRunStats()
                  levelRun.currentLevel = 1
                  levelRun.isActive = false
                  // Dismiss to the Home tab in a single animation by collapsing
                  // the LevelSystemSelectionView underneath us. SwiftUI will
                  // dismantle this LevelGameView automatically as the parent
                  // fullScreenCover goes away — calling dismiss() here would
                  // produce a visible flash of the selection screen.
                  NotificationCenter.default.post(
                    name: NSNotification.Name("DismissToHome"),
                    object: nil
                  )
                }) {
                  Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.primary)
                    .frame(width: 32, height: 32)
                    .background(
                      Circle()
                        .fill(Color.white.opacity(0.8))
                        .shadow(
                          color: .black.opacity(0.1),
                          radius: 4,
                          x: 0,
                          y: 2
                        )
                    )
                }

                Spacer()

                // Dev-only skip button
                if levelRun.shouldShowDevTools, !levelRun.isCompleted {
                  Button(action: {
                    levelRun.skipToNextLevel()
                    startNewLevel()
                  }) {
                    Text("🔧 Skip")
                      .font(.system(size: 12, weight: .medium))
                      .foregroundColor(.orange)
                      .padding(.horizontal, 12)
                      .padding(.vertical, 6)
                      .background(
                        RoundedRectangle(cornerRadius: 12)
                          .fill(Color.orange.opacity(0.1))
                          .overlay(
                            RoundedRectangle(cornerRadius: 12)
                              .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                          )
                      )
                  }
                }
              }
              .padding(.horizontal, 20)
              .padding(.top, 10)

              // Top bar: Score/Target on left, Lives on right
              HStack {
                // Top left: Score and Target
                VStack(alignment: .leading, spacing: 4) {
                  Text("Score: \(levelRun.currentScore)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                  Text("Target: \(levelRun.getRequiredScore())")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                }

                Spacer()

                // Top right: Heart icon with remaining lives (increased by 30%)
                HStack(spacing: 6) {
                  Image("Heart")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 26, height: 26)
                  Text("\(levelRun.remainingLives)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                }
              }
              .padding(.horizontal, 20)
              .padding(.top, 20)

              // Center: Level X title (styled like Level Complete, without icon)
              Text("Level \(levelRun.currentLevel)")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(
                  LinearGradient(
                    gradient: Gradient(colors: [.purple, .pink]),
                    startPoint: .leading,
                    endPoint: .trailing
                  )
                )
                .padding(.top, 16) // Reduced by 20% (from 20 to 16)

              Spacer()

              // Timer
              VStack(spacing: 8) {
                Text("\(Int(timeRemaining.rounded(.up)))s")
                  .font(.system(size: 64, weight: .bold, design: .rounded))
                  .foregroundColor(timeRemaining <= 5 ? .red : .primary)
                  .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

                Text("Time Remaining")
                  .font(.title3)
                  .fontWeight(.medium)
                  .foregroundColor(.secondary)
              }
              .padding(.bottom, 30)

              // Round Progress Bar (if level has time limit and is not
              // non-punitive refresh)
              if let levelConfig = levelRun.currentLevelConfig,
                 levelConfig.hasTimeLimit, !levelConfig.isNonPunitiveRefresh
              {
                VStack(spacing: 8) {
                  Text("Round Time")
                    .font(.caption)
                    .foregroundColor(.secondary)

                  GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                      // Background bar
                      RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 8)

                      // Progress bar
                      RoundedRectangle(cornerRadius: 4)
                        .fill(roundTimeRemaining >
                          (levelConfig.timePerResponse ?? 1.0) * 0.3 ? Color
                          .green : Color.red)
                        .frame(
                          width: geometry.size
                            .width *
                            (roundTimeRemaining /
                              (levelConfig.timePerResponse ?? 1.0)),
                          height: 8
                        )
                        .animation(
                          .linear(duration: 0.1),
                          value: roundTimeRemaining
                        )
                    }
                  }
                  .frame(height: 8)
                  .padding(.horizontal, 40)
                }
                .padding(.bottom, 20)
              }

              // 2x2 Grid
              VStack(spacing: 20) {
                HStack(spacing: 20) {
                  if levelRun.gameType == .colorOnly {
                    ColorTile(
                      color: tiles.count > 0 ? tiles[0] : .gray,
                      action: { handleTileTap(0) }
                    )
                    ColorTile(
                      color: tiles.count > 1 ? tiles[1] : .gray,
                      action: { handleTileTap(1) }
                    )
                  } else {
                    ColorAndTextTile(
                      tile: tilesWithText.count > 0 ? tilesWithText[0] : Tile(
                        backgroundColor: .gray,
                        textLabel: "gray"
                      ),
                      action: { handleTileTap(0) }
                    )
                    ColorAndTextTile(
                      tile: tilesWithText.count > 1 ? tilesWithText[1] : Tile(
                        backgroundColor: .gray,
                        textLabel: "gray"
                      ),
                      action: { handleTileTap(1) }
                    )
                  }
                }
                HStack(spacing: 20) {
                  if levelRun.gameType == .colorOnly {
                    ColorTile(
                      color: tiles.count > 2 ? tiles[2] : .gray,
                      action: { handleTileTap(2) }
                    )
                    ColorTile(
                      color: tiles.count > 3 ? tiles[3] : .gray,
                      action: { handleTileTap(3) }
                    )
                  } else {
                    ColorAndTextTile(
                      tile: tilesWithText.count > 2 ? tilesWithText[2] : Tile(
                        backgroundColor: .gray,
                        textLabel: "gray"
                      ),
                      action: { handleTileTap(2) }
                    )
                    ColorAndTextTile(
                      tile: tilesWithText.count > 3 ? tilesWithText[3] : Tile(
                        backgroundColor: .gray,
                        textLabel: "gray"
                      ),
                      action: { handleTileTap(3) }
                    )
                  }
                }
              }
              .padding(.bottom, 40)

              Spacer()
            }
            .padding()

            // Error flash overlay
            if showingErrorFlash {
              Color.red.opacity(0.3)
                .ignoresSafeArea()
                .transition(.opacity)
            }

            // Streak animation overlay
            if showStreakAnimation {
              StreakAnimationView(streakCount: streakDisplayCount)
                .transition(.asymmetric(
                  insertion: .scale.combined(with: .opacity),
                  removal: .opacity
                ))
                .zIndex(1000)
            }

            // Level intro pop-in overlay
            if showLevelIntro {
              LevelIntroView(
                levelRun: levelRun,
                onDismiss: {
                  dismissLevelIntroAndStart()
                }
              )
              .zIndex(2000)
              .transition(.opacity)
            }
          }
        }
      }
      #if !os(macOS)
      .navigationBarHidden(true)
      #endif
      .onAppear {
        startLevel()
      }
      .onDisappear {
        endGameSession()
      }
      #if canImport(UIKit)
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
        pauseTimer()
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
        resumeTimer()
      }
      #elseif os(macOS)
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
        pauseTimer()
      }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
        resumeTimer()
      }
      #endif
      .onChange(of: levelRun.lastBonusEarned) { newValue in
        if newValue > 0 {
          streakDisplayCount = levelRun.currentStreak
          showStreakAnimation = true
          // Reset the trigger after a short delay
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard isGameSessionActive else { return }
            levelRun.lastBonusEarned = 0
          }
          // Hide animation after fade out completes (1.8 seconds total: 1.5s
          // visible + 0.3s fade)
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard isGameSessionActive else { return }
            showStreakAnimation = false
          }
        }
      }
    }
    #if !os(macOS)
    .navigationViewStyle(StackNavigationViewStyle())
    #endif
  }

  private func handleTileTap(_ index: Int) {
    guard isGameActive, isGameSessionActive, !isLevelComplete,
          !isLevelFailed else { return }

    // Block additional taps in this round; startNewRound() will re-enable.
    isGameActive = false

    // End round timer immediately
    endRoundTimer()

    let isCorrect: Bool
    let tappedBackgroundColor: Color

    if levelRun.gameType == .colorOnly {
      // Color Only mode: correctness depends ONLY on background color
      guard index < tiles.count else { return }
      tappedBackgroundColor = tiles[index]
      isCorrect = tappedBackgroundColor != announcedColor
    } else {
      // Color + Text mode: correctness depends on BOTH background color AND
      // text label
      guard index < tilesWithText.count else { return }
      let tappedTile = tilesWithText[index]
      tappedBackgroundColor = tappedTile.backgroundColor
      let announcedColorName = colorName(for: announcedColor)

      // Wrong if background matches OR text label matches
      // Correct only if BOTH background ≠ announced AND text ≠ announced
      let backgroundMatches = tappedTile.backgroundColor == announcedColor
      let textMatches = tappedTile.textLabel.lowercased() == announcedColorName
        .lowercased()
      isCorrect = !backgroundMatches && !textMatches
    }

    // Update tracking: track consecutive correct taps per position
    if isCorrect {
      // This position was correct - increment counter
      consecutiveCorrectByPosition[index] =
        (consecutiveCorrectByPosition[index] ?? 0) + 1
    } else {
      // This position was incorrect - reset counter for this position
      consecutiveCorrectByPosition[index] = 0
    }

    print(
      "Tile tapped: index \(index), \(colorName(for: tappedBackgroundColor)), Announced: \(colorName(for: announcedColor)), Correct: \(isCorrect), Consecutive correct for this position: \(consecutiveCorrectByPosition[index] ?? 0)"
    )

    if isCorrect {
      // Correct tap
      levelRun.addCorrectAnswer()
      print("Score after correct: \(levelRun.currentScore)")
      hapticsService.lightImpact()
    } else {
      // Incorrect tap
      levelRun.addWrongAnswer()
      print("Score after incorrect: \(levelRun.currentScore)")
      hapticsService.heavyImpact()
      showErrorFlash()
    }

    // Check if level is complete or failed
    checkLevelStatus()

    // Wait 300ms then start next round
    pendingNextRound?.cancel()
    let item = DispatchWorkItem {
      if isGameSessionActive, !isLevelComplete, !isLevelFailed {
        startNewRound()
      }
    }
    pendingNextRound = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
  }

  private func checkLevelStatus() {
    guard let levelConfig = levelRun.currentLevelConfig else { return }

    // Only check for failure conditions during gameplay
    // Level completion is checked when timer runs out

    // Check if no lives remaining (game over)
    if levelRun.isGameOver {
      isLevelFailed = true
      failedReason = .maxMistakes // Reuse this reason for "out of lives"
      return
    }
  }

  private func startLevel() {
    guard let levelConfig = levelRun.currentLevelConfig else { return }

    // Show level intro pop-in first
    showLevelIntro = true

    // Auto-dismiss after 3 seconds
    pendingIntroDismiss?.cancel()
    let item = DispatchWorkItem {
      if showLevelIntro {
        dismissLevelIntroAndStart()
      }
    }
    pendingIntroDismiss = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
  }

  private func dismissLevelIntroAndStart() {
    showLevelIntro = false

    guard let levelConfig = levelRun.currentLevelConfig else { return }

    isGameSessionActive = true
    isGameActive = false

    // Reset level-specific stats
    levelRun.startLevel()

    // Reset timers
    timeRemaining = Double(levelConfig.durationSeconds)
    roundTimeRemaining = 0

    // Reset color tracking
    recentAnnouncedColors = []

    // Reset position tracking for new level
    consecutiveCorrectByPosition = [:]

    // Start global timer
    gameTimer = Timer
      .scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        guard isGameSessionActive else { return }
        if timeRemaining > 0 {
          timeRemaining -= 0.1
        } else {
          handleTimeUp()
        }
      }

    // Start first round
    startNewRound()
  }

  private func startNewLevel() {
    guard isLevelFailed || isLevelComplete else { return }
    endGameSession() // Stop previous timer
    isLevelComplete = false
    isLevelFailed = false
    levelRun.resetLevelStats()
    startLevel()
  }

  private func startNewRound() {
    isGameActive = false

    // Note: We DON'T reset consecutiveCorrectByPosition here because we want to
    // track
    // across rounds to prevent the same position from being correct 4+ times in
    // a row
    // The tracking will be reset when a position becomes incorrect or at level
    // start

    // Store previous tiles for comparison
    if levelRun.gameType == .colorOnly {
      previousTiles = tiles
    } else {
      previousTilesWithText = tilesWithText
    }

    // Select random announced color with repeat prevention
    announcedColor = selectAnnouncedColor()

    // Update recent colors tracking
    updateRecentColors(announcedColor)

    // Speak the announced color
    let colorNameString = colorName(for: announcedColor)
    speechService.speak(colorNameString)

    // Build valid grid based on game type
    if levelRun.gameType == .colorOnly {
      tiles = buildValidGrid()
    } else {
      tilesWithText = buildValidGridWithText()
    }

    // Enable game after a brief delay
    pendingActivation?.cancel()
    let item = DispatchWorkItem {
      isGameActive = true

      // Start round timer if level has time limit
      if let levelConfig = levelRun.currentLevelConfig,
         levelConfig.hasTimeLimit
      {
        startRoundTimer(timeLimit: levelConfig.timePerResponse ?? 1.5)
      }
    }
    pendingActivation = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
  }

  // Refresh board only (for non-punitive refresh levels 9-10)
  // Keeps the same announced color, re-speaks it for audio reinforcement, and
  // reshuffles the tiles
  private func refreshBoardOnly() {
    isGameActive = false

    // Note: We DON'T reset consecutiveCorrectByPosition here because tiles
    // change position
    // but we still want to track to prevent the same position from being
    // correct 4+ times

    // Store previous tiles for comparison
    if levelRun.gameType == .colorOnly {
      previousTiles = tiles
    } else {
      previousTilesWithText = tilesWithText
    }

    // Keep the same announced color but re-speak it so the audio cue stays in
    // sync with the visual board (BUG-008).
    speechService.speak(colorName(for: announcedColor))

    // Build valid grid based on game type (with the same announced color)
    if levelRun.gameType == .colorOnly {
      tiles = buildValidGrid()
    } else {
      tilesWithText = buildValidGridWithText()
    }

    // Enable game after a brief delay
    pendingActivation?.cancel()
    let item = DispatchWorkItem {
      isGameActive = true

      // Restart round timer for non-punitive refresh
      if let levelConfig = levelRun.currentLevelConfig,
         levelConfig.hasTimeLimit
      {
        startRoundTimer(timeLimit: levelConfig.timePerResponse ?? 1.5)
      }
    }
    pendingActivation = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
  }

  private func buildValidGrid() -> [Color] {
    var attempts = 0
    let maxAttempts = 20

    while attempts < maxAttempts {
      var grid: [Color] = []
      let nonAnnouncedColors = colorPalette.filter { $0 != announcedColor }

      // CRITICAL: Guarantee at least 1 incorrect (announced color) and 1 correct (different color)
      // Add the announced color at least once (incorrect tile)
      grid.append(announcedColor)

      // Add at least one different color (correct tile)
      guard let differentColor = nonAnnouncedColors.randomElement() else {
        attempts += 1
        continue
      }
      grid.append(differentColor)

      // Fill remaining 2 slots: ensure we maintain at least 1 correct and 1
      // incorrect
      // Strategy: Add 1 more announced color and 1 more different color
      if grid.count < 4 {
        grid.append(announcedColor) // Add another incorrect tile
      }
      if grid.count < 4 {
        // Add another correct tile (different from announced)
        if let anotherDifferentColor = nonAnnouncedColors.randomElement() {
          grid.append(anotherDifferentColor)
        } else {
          grid.append(differentColor) // Fallback to the same different color
        }
      }

      // Shuffle the grid
      var shuffledGrid = grid.shuffled()

      // Ensure positions that have been correct 4+ times are NOT correct in
      // this grid
      // BUT always maintain at least one correct tile
      var positionsToMakeIncorrect: [Int] = []
      for (position, consecutiveCount) in consecutiveCorrectByPosition {
        guard position < shuffledGrid.count else { continue }
        if consecutiveCount >= 4 {
          positionsToMakeIncorrect.append(position)
        }
      }

      // If we need to make positions incorrect, do it carefully
      if !positionsToMakeIncorrect.isEmpty {
        // Count how many correct tiles we currently have
        let correctTilesCount = shuffledGrid.filter { $0 != announcedColor }
          .count

        // We need at least 1 correct tile, so if making positions incorrect
        // would leave us with 0, skip this grid
        let wouldLeaveCorrectTiles = correctTilesCount -
          positionsToMakeIncorrect.count
        if wouldLeaveCorrectTiles < 1 {
          // This grid would have no correct tiles, try again
          attempts += 1
          continue
        }

        // Make the positions incorrect by setting them to announced color
        for position in positionsToMakeIncorrect {
          shuffledGrid[position] = announcedColor
        }
      }

      // Final verification: ensure we have at least 1 correct and 1 incorrect
      let finalCorrectCount = shuffledGrid.filter { $0 != announcedColor }.count
      let finalIncorrectCount = shuffledGrid.filter { $0 == announcedColor }
        .count

      if finalCorrectCount >= 1, finalIncorrectCount >= 1 {
        // Check if different from previous round
        if shuffledGrid != previousTiles {
          return shuffledGrid
        }
      }

      attempts += 1
    }

    // Fallback: guarantee at least 1 correct and 1 incorrect
    let nonAnnouncedColors = colorPalette.filter { $0 != announcedColor }
    guard let correctColor1 = nonAnnouncedColors.randomElement() else {
      // If no non-announced colors available (shouldn't happen), use a fallback
      return [announcedColor, .red, .blue, .green]
        .filter { $0 != announcedColor || $0 == announcedColor }
    }
    let correctColor2 = nonAnnouncedColors.count > 1 ? nonAnnouncedColors
      .filter { $0 != correctColor1 }
      .randomElement() ?? correctColor1 : correctColor1

    var fallbackGrid = [
      announcedColor,
      announcedColor,
      correctColor1,
      correctColor2,
    ]

    // Count correct tiles before modifications
    var correctTilesCount = fallbackGrid.filter { $0 != announcedColor }.count
    var positionsToMakeIncorrect: [Int] = []
    for (position, consecutiveCount) in consecutiveCorrectByPosition {
      guard position < fallbackGrid.count else { continue }
      if consecutiveCount >= 4 {
        positionsToMakeIncorrect.append(position)
      }
    }

    // Only make positions incorrect if we'll still have at least 1 correct tile
    if correctTilesCount - positionsToMakeIncorrect.count >= 1 {
      for position in positionsToMakeIncorrect {
        fallbackGrid[position] = announcedColor
      }
    }

    // Final verification of fallback
    let finalCorrect = fallbackGrid.filter { $0 != announcedColor }.count
    let finalIncorrect = fallbackGrid.filter { $0 == announcedColor }.count

    if finalCorrect >= 1, finalIncorrect >= 1 {
      return fallbackGrid.shuffled()
    } else {
      // Last resort: force 2 correct and 2 incorrect
      return [announcedColor, announcedColor, correctColor1, correctColor2]
        .shuffled()
    }
  }

  private func buildValidGridWithText() -> [Tile] {
    var attempts = 0
    let maxAttempts = 20 // Increased attempts for better reliability
    let announcedColorName = colorName(for: announcedColor)
    let colorNames = colorPalette.map { colorName(for: $0) }

    while attempts < maxAttempts {
      var grid: [Tile] = []

      // Requirement 1: At least one tile with background = announced color
      // (wrong by background)
      // This tile can have any text label
      let wrongByBackgroundLabel = colorNames.randomElement() ?? "red"
      grid.append(Tile(
        backgroundColor: announcedColor,
        textLabel: wrongByBackgroundLabel
      ))

      // Requirement 2: At least one tile with text label = announced color name
      // (wrong by text)
      // This tile must have background ≠ announced color
      let nonAnnouncedColors = colorPalette.filter { $0 != announcedColor }
      guard let wrongByTextColor = nonAnnouncedColors.randomElement() else {
        attempts += 1
        continue
      }
      grid.append(Tile(
        backgroundColor: wrongByTextColor,
        textLabel: announcedColorName
      ))

      // Requirement 3: At least one tile that is correct (both background ≠
      // announced AND text ≠ announced)
      // CRITICAL: This must always exist
      guard let correctColor = nonAnnouncedColors.randomElement() else {
        attempts += 1
        continue
      }
      let correctColorName = colorName(for: correctColor)
      let nonMatchingLabels = colorNames
        .filter {
          $0.lowercased() != announcedColorName.lowercased() && $0
            .lowercased() != correctColorName.lowercased()
        }
      guard let correctLabel = nonMatchingLabels.randomElement() ?? colorNames
        .first(where: { $0.lowercased() != announcedColorName.lowercased() })
      else {
        attempts += 1
        continue
      }
      grid.append(Tile(backgroundColor: correctColor, textLabel: correctLabel))

      // Fill remaining slot (4th tile) - ensure we maintain at least 1 correct
      // tile
      // We already have: 1 wrong by background, 1 wrong by text, 1 correct
      // For the 4th tile, add another incorrect tile (wrong by background) to
      // maintain balance
      if grid.count < 4 {
        let fourthTileLabel = colorNames.randomElement() ?? "blue"
        grid.append(Tile(
          backgroundColor: announcedColor,
          textLabel: fourthTileLabel
        ))
      }

      // Validate that we have all three required tile types
      let hasWrongByBackground = grid
        .contains { $0.backgroundColor == announcedColor }
      let hasWrongByText = grid
        .contains {
          $0.textLabel.lowercased() == announcedColorName.lowercased() && $0
            .backgroundColor != announcedColor
        }
      let correctTiles = grid.filter { tile in
        tile.backgroundColor != announcedColor && tile.textLabel
          .lowercased() != announcedColorName.lowercased()
      }
      let hasCorrectTile = !correctTiles.isEmpty

      // CRITICAL: Must have at least one correct tile and at least one incorrect tile
      guard hasWrongByBackground, hasWrongByText, hasCorrectTile else {
        attempts += 1
        continue
      }

      // Final check: ensure we have at least 1 correct and at least 1 incorrect
      let incorrectTiles = grid.filter { tile in
        tile.backgroundColor == announcedColor || tile.textLabel
          .lowercased() == announcedColorName.lowercased()
      }
      guard incorrectTiles.count >= 1, correctTiles.count >= 1 else {
        attempts += 1
        continue
      }

      // Shuffle the grid
      var shuffledGrid = grid.shuffled()

      // Ensure positions that have been correct 4+ times are NOT correct in
      // this grid
      // BUT always maintain at least one correct tile
      var positionsToMakeIncorrect: [Int] = []
      for (position, consecutiveCount) in consecutiveCorrectByPosition {
        guard position < shuffledGrid.count else { continue }
        if consecutiveCount >= 4 {
          let tile = shuffledGrid[position]
          // Check if this position is currently correct
          let backgroundMatches = tile.backgroundColor == announcedColor
          let textMatches = tile.textLabel.lowercased() == announcedColorName
            .lowercased()
          if !backgroundMatches, !textMatches {
            // This position is correct and needs to be made incorrect
            positionsToMakeIncorrect.append(position)
          }
        }
      }

      // If we need to make positions incorrect, do it carefully
      if !positionsToMakeIncorrect.isEmpty {
        // Count how many correct tiles we currently have
        let correctTilesCount = shuffledGrid.filter { tile in
          tile.backgroundColor != announcedColor && tile.textLabel
            .lowercased() != announcedColorName.lowercased()
        }.count

        // We need at least 1 correct tile, so if making positions incorrect
        // would leave us with 0, skip this grid
        let wouldLeaveCorrectTiles = correctTilesCount -
          positionsToMakeIncorrect.count
        if wouldLeaveCorrectTiles < 1 {
          // This grid would have no correct tiles, try again
          attempts += 1
          continue
        }

        // Make the positions incorrect (either by background or text matching
        // announced)
        for position in positionsToMakeIncorrect {
          // Make it wrong by setting background to announced color (simpler)
          shuffledGrid[position] = Tile(
            backgroundColor: announcedColor,
            textLabel: colorNames.randomElement() ?? "blue"
          )
        }
      }

      // CRITICAL: Final verification - must have at least one correct tile AND one incorrect tile
      let finalCorrectTiles = shuffledGrid.filter { tile in
        tile.backgroundColor != announcedColor && tile.textLabel
          .lowercased() != announcedColorName.lowercased()
      }
      let finalIncorrectTiles = shuffledGrid.filter { tile in
        tile.backgroundColor == announcedColor || tile.textLabel
          .lowercased() == announcedColorName.lowercased()
      }

      guard finalCorrectTiles.count >= 1, finalIncorrectTiles.count >= 1 else {
        // Must have at least 1 correct and 1 incorrect tile, try again
        attempts += 1
        continue
      }

      // Check if different from previous round
      if shuffledGrid != previousTilesWithText {
        return shuffledGrid
      }

      attempts += 1
    }

    // Fallback: ensure all three types exist and ALWAYS have at least one correct tile
    var fallbackGrid: [Tile] = []
    // Wrong by background
    fallbackGrid.append(Tile(
      backgroundColor: announcedColor,
      textLabel: "blue"
    ))
    // Wrong by text
    let fallbackWrongByTextColor = colorPalette
      .first { $0 != announcedColor } ?? .blue
    fallbackGrid.append(Tile(
      backgroundColor: fallbackWrongByTextColor,
      textLabel: announcedColorName
    ))
    // CRITICAL: At least one correct tile (background ≠ announced AND text ≠ announced)
    let fallbackCorrectColor = colorPalette
      .first { $0 != announcedColor && $0 != fallbackWrongByTextColor } ??
      .green
    let fallbackCorrectColorName = colorName(for: fallbackCorrectColor)
    // Ensure the label is different from announced color name
    let fallbackCorrectLabel = colorNames
      .first {
        $0.lowercased() != announcedColorName.lowercased() && $0
          .lowercased() != fallbackCorrectColorName.lowercased()
      } ?? "red"
    fallbackGrid.append(Tile(
      backgroundColor: fallbackCorrectColor,
      textLabel: fallbackCorrectLabel
    ))
    // Fill 4th slot - make it incorrect to be safe
    fallbackGrid.append(Tile(
      backgroundColor: announcedColor,
      textLabel: colorNames.randomElement() ?? "yellow"
    ))

    // Ensure positions with 4+ consecutive correct are forced to be incorrect
    // BUT always maintain at least one correct tile
    var shuffledFallback = fallbackGrid.shuffled()

    // Count correct tiles before modifications
    var correctTilesCount = shuffledFallback.filter { tile in
      tile.backgroundColor != announcedColor && tile.textLabel
        .lowercased() != announcedColorName.lowercased()
    }.count

    // CRITICAL: If we have no correct tiles in fallback, force at least one
    if correctTilesCount == 0 {
      // Find a position and make it correct
      if let firstPosition = shuffledFallback.indices.first {
        let safeColor = colorPalette.first { $0 != announcedColor } ?? .blue
        let safeColorName = colorName(for: safeColor)
        let safeLabel = colorNames
          .first {
            $0.lowercased() != announcedColorName.lowercased() && $0
              .lowercased() != safeColorName.lowercased()
          } ?? "red"
        shuffledFallback[firstPosition] = Tile(
          backgroundColor: safeColor,
          textLabel: safeLabel
        )
        correctTilesCount = 1
      }
    }

    var positionsToMakeIncorrect: [Int] = []
    for (position, consecutiveCount) in consecutiveCorrectByPosition {
      guard position < shuffledFallback.count else { continue }
      if consecutiveCount >= 4 {
        let tile = shuffledFallback[position]
        // Check if this position is currently correct
        let backgroundMatches = tile.backgroundColor == announcedColor
        let textMatches = tile.textLabel.lowercased() == announcedColorName
          .lowercased()
        if !backgroundMatches, !textMatches {
          // This position is correct and needs to be made incorrect
          positionsToMakeIncorrect.append(position)
        }
      }
    }

    // Only make positions incorrect if we'll still have at least 1 correct tile
    if correctTilesCount - positionsToMakeIncorrect.count >= 1 {
      for position in positionsToMakeIncorrect {
        // Make it wrong by setting background to announced color
        shuffledFallback[position] = Tile(
          backgroundColor: announcedColor,
          textLabel: colorNames.randomElement() ?? "blue"
        )
      }
    }

    // FINAL CRITICAL CHECK: Verify we have at least one correct tile
    let finalCorrectCount = shuffledFallback.filter { tile in
      tile.backgroundColor != announcedColor && tile.textLabel
        .lowercased() != announcedColorName.lowercased()
    }.count

    // If somehow we still have no correct tiles, force one
    if finalCorrectCount == 0 {
      // Find first position and make it correct
      if let firstPosition = shuffledFallback.indices.first {
        let safeColor = colorPalette.first { $0 != announcedColor } ?? .blue
        let safeColorName = colorName(for: safeColor)
        let safeLabel = colorNames
          .first {
            $0.lowercased() != announcedColorName.lowercased() && $0
              .lowercased() != safeColorName.lowercased()
          } ?? "red"
        shuffledFallback[firstPosition] = Tile(
          backgroundColor: safeColor,
          textLabel: safeLabel
        )
      }
    }

    return shuffledFallback
  }

  private func startRoundTimer(timeLimit: Double) {
    endRoundTimer()
    roundTimeRemaining = timeLimit
    isRoundTimerActive = true

    roundTimer = Timer
      .scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        guard isRoundTimerActive else { return }
        roundTimeRemaining -= 0.1

        if roundTimeRemaining <= 0 {
          handleRoundTimeout()
        }
      }
  }

  private func endRoundTimer() {
    roundTimer?.invalidate()
    roundTimer = nil
    isRoundTimerActive = false
  }

  private func handleRoundTimeout() {
    // Only check if game session is active and level is not complete/failed
    // Don't check isGameActive here because it might be false when timer
    // expires
    guard isGameSessionActive, !isLevelComplete, !isLevelFailed else {
      print(
        "Timeout blocked: isGameSessionActive=\(isGameSessionActive), isLevelComplete=\(isLevelComplete), isLevelFailed=\(isLevelFailed)"
      )
      return
    }

    // Check if this is a non-punitive refresh level (9-10)
    if let levelConfig = levelRun.currentLevelConfig,
       levelConfig.isNonPunitiveRefresh
    {
      // Non-punitive refresh: just refresh the board, keep same announced
      // color, no penalty
      endRoundTimer()
      refreshBoardOnly()
    } else {
      // Regular timeout: apply penalty
      print("Applying timeout penalty: -5 points")
      levelRun.addTimeout()
      print("Score after timeout: \(levelRun.currentScore)")
      hapticsService.heavyImpact()
      showErrorFlash()

      endRoundTimer()
      checkLevelStatus()

      pendingNextRound?.cancel()
      let item = DispatchWorkItem {
        if isGameSessionActive, !isLevelComplete, !isLevelFailed {
          startNewRound()
        }
      }
      pendingNextRound = item
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }
  }

  private func handleTimeUp() {
    endGameSession()

    // Check if level was completed successfully
    guard let levelConfig = levelRun.currentLevelConfig else {
      isLevelFailed = true
      failedReason = .insufficientScore
      return
    }

    // Check if score meets requirement (streak bonuses are already included in
    // currentScore)
    let requiredScore = levelRun.getRequiredScore()
    if levelRun.getCurrentLevelScore() >= requiredScore {
      isLevelComplete = true
    } else {
      // Level failed due to insufficient score - lose 1 life
      levelRun.loseLife()

      isLevelFailed = true
      failedReason = .insufficientScore

      // Check if no lives remaining (game over)
      if levelRun.isGameOver {
        failedReason = .maxMistakes // Reuse this reason for "out of lives"
      }
    }
  }

  private func showErrorFlash() {
    withAnimation(.easeInOut(duration: 0.1)) {
      showingErrorFlash = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      guard isGameSessionActive else { return }
      withAnimation(.easeInOut(duration: 0.1)) {
        showingErrorFlash = false
      }
    }
  }

  private func colorName(for color: Color) -> String {
    if color == .red { return "red" }
    if color == .blue { return "blue" }
    if color == .green { return "green" }
    if color == .yellow { return "yellow" }
    return "unknown"
  }

  private func selectAnnouncedColor() -> Color {
    guard recentAnnouncedColors.count >= 2 else {
      return colorPalette.randomElement() ?? .red
    }

    let lastTwoColors = Array(recentAnnouncedColors.suffix(2))
    if lastTwoColors[0] == lastTwoColors[1] {
      let excludedColor = lastTwoColors[0]
      let availableColors = colorPalette.filter { $0 != excludedColor }
      return availableColors.randomElement() ?? .red
    }

    return colorPalette.randomElement() ?? .red
  }

  private func updateRecentColors(_ color: Color) {
    recentAnnouncedColors.append(color)
    if recentAnnouncedColors.count > 2 {
      recentAnnouncedColors.removeFirst()
    }
  }

  private func endGameSession() {
    isGameSessionActive = false
    isGameActive = false
    gameTimer?.invalidate()
    gameTimer = nil
    endRoundTimer()

    pendingNextRound?.cancel()
    pendingNextRound = nil
    pendingIntroDismiss?.cancel()
    pendingIntroDismiss = nil
    pendingActivation?.cancel()
    pendingActivation = nil
  }

  private func pauseTimer() {
    guard isGameSessionActive else { return }
    backgroundTime = Date()
    gameTimer?.invalidate()
    gameTimer = nil

    if isRoundTimerActive {
      roundTimer?.invalidate()
      roundTimer = nil
    }
  }

  private func resumeTimer() {
    guard isGameSessionActive, let backgroundTime else { return }

    let elapsedTime = Date().timeIntervalSince(backgroundTime)
    timeRemaining -= elapsedTime

    if timeRemaining <= 0 {
      handleTimeUp()
      return
    }

    // Re-anchor the player by re-speaking the announced color (BUG-012).
    speechService.speak(colorName(for: announcedColor))

    gameTimer = Timer
      .scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        guard isGameSessionActive else { return }
        if timeRemaining > 0 {
          timeRemaining -= 0.1
        } else {
          handleTimeUp()
        }
      }

    if isRoundTimerActive {
      startRoundTimer(timeLimit: roundTimeRemaining)
    }

    self.backgroundTime = nil
  }
}

// MARK: - Level Intro View

struct LevelIntroView: View {
  @ObservedObject var levelRun: LevelRun
  let onDismiss: () -> Void

  private var levelDescription: String {
    guard let levelConfig = levelRun.currentLevelConfig else { return "" }

    // Special case for Levels 1 and 2
    if levelRun.currentLevel == 1 || levelRun.currentLevel == 2 {
      return "Warm-up level"
    }

    // Special case for Levels 9 and 10
    if levelRun.currentLevel == 9 || levelRun.currentLevel == 10 {
      return "Colors will change every second"
    }

    var description = ""

    if levelConfig.hasTimeLimit {
      if levelConfig.isNonPunitiveRefresh {
        description = "Colors change every second, but no points are lost if you don't tap."
      } else {
        let timeLimit = String(format: "%.1f", levelConfig.timePerResponse ?? 0)
        description = "You have \(timeLimit)s to tap fast or lose 5 pts!"
      }
    } else {
      description = "No time limit per answer. Take your time!"
    }

    return description
  }

  var body: some View {
    ZStack {
      // Semi-transparent background
      Color.black.opacity(0.5)
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // Three stars at the top - middle star larger and elevated
        ZStack(alignment: .bottom) {
          // Side stars aligned horizontally
          HStack(spacing: 8) {
            Image("Mediumstar")
              .resizable()
              .scaledToFit()
              .frame(width: 40, height: 40)

            Spacer()
              .frame(width: 60) // Space for middle star

            Image("Mediumstar")
              .resizable()
              .scaledToFit()
              .frame(width: 40, height: 40)
          }

          // Middle star - larger and slightly higher
          Image("Bigstar")
            .resizable()
            .scaledToFit()
            .frame(width: 70, height: 70)
            .offset(y: -8) // Slightly elevated
        }
        .frame(height: 70)
        .padding(.bottom, 16)

        // Pop-in card with light pink background
        ZStack(alignment: .topTrailing) {
          VStack(spacing: 20) {
            // "Targeted score" text - split into two lines, extra bold, 30%
            // larger, minimal spacing
            VStack(spacing: -3) { // Negative spacing to bring lines closer (10%
              // reduction from 0)
              Text("Targeted")
                .font(.system(
                  size: 30,
                  weight: .black
                )) // 23 * 1.3 = 29.9 ≈ 30, extra bold
                .foregroundColor(Color(hex: "E60076"))

              Text("score")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(Color(hex: "E60076"))
            }
            .padding(.top, 8)

            // Score container with light pink background - reduced height by
            // 15%
            Text("\(levelRun.getRequiredScore())")
              .font(.system(size: 48, weight: .bold))
              .foregroundColor(Color(hex: "E60076"))
              .frame(minWidth: 120)
              .padding(.horizontal, 24)
              .padding(.vertical, 10) // Reduced by 15% (12 * 0.85 = 10.2 ≈ 10)
              .background(
                RoundedRectangle(cornerRadius: 12)
                  .fill(Color(hex: "FFC9C9"))
                  .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
              )

            // Level description with bomb icon - 20% larger, text horizontally
            // aligned with icon
            if !levelDescription.isEmpty {
              HStack(alignment: .center, spacing: 8) {
                Image("Bomb")
                  .resizable()
                  .scaledToFit()
                  .frame(width: 29, height: 29) // 24 * 1.2 = 28.8 ≈ 29

                Text(levelDescription)
                  .font(.system(size: 14, weight: .regular))
                  .foregroundColor(.primary)
                  .multilineTextAlignment(.leading)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .padding(.horizontal, 20)
              .padding(.bottom, 8)
            }
          }

          // Close button (X) - simple icon, fully top-right corner, reduced
          // size
          Button(action: onDismiss) {
            Image(systemName: "xmark")
              .font(.system(
                size: 18,
                weight: .semibold
              )) // Reduced by 10% (20 * 0.9 = 18)
              .foregroundColor(.gray)
          }
          .offset(
            x: 8,
            y: -8
          ) // Move further right and up to be fully in corner
        }
        .padding(24)
        .frame(width: 224) // Reduced by 30% (320 * 0.7 = 224)
        .background(
          RoundedRectangle(cornerRadius: 20)
            .fill(Color(hex: "FEF2F2"))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

// MARK: - Streak Animation View

struct StreakAnimationView: View {
  let streakCount: Int
  @State private var scale: CGFloat = 0.5
  @State private var opacity: Double = 0.0

  var body: some View {
    VStack {
      Spacer()
        .frame(height: 200) // Position below the level title

      HStack(spacing: 8) {
        Text("🔥")
          .font(.system(size: 32))

        Text("\(streakCount) in a row!")
          .font(.system(size: 24, weight: .bold, design: .rounded))
          .foregroundColor(.white)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .background(
        LinearGradient(
          gradient: Gradient(colors: [
            Color.orange.opacity(0.9),
            Color.red.opacity(0.9),
          ]),
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .cornerRadius(20)
      .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
      .scaleEffect(scale)
      .opacity(opacity)
      .onAppear {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
          scale = 1.0
          opacity = 1.0
        }

        // Fade out after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
          withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0.0
            scale = 0.8
          }
        }
      }

      Spacer()
    }
    .allowsHitTesting(false) // Don't block touches
  }
}

// MARK: - Level Complete View

struct LevelCompleteView: View {
  @ObservedObject var levelRun: LevelRun
  let onNextLevel: () -> Void
  let onBackToHome: () -> Void

  // Calculate final score (streak bonuses are already included in currentScore)
  private var finalLevelScore: Int {
    // currentScore already includes all points, penalties, and streak bonuses
    levelRun.getCurrentLevelScore()
  }

  // Score breakdown components
  private var correctAnswersPoints: Int {
    levelRun
      .levelBasePoints // Only base points from correct answers, excluding
    // bonuses
  }

  private var mistakesPenalty: Int {
    // Show penalties from wrong taps (only point deductions, no life cost)
    levelRun.levelWrongTaps * -10
  }

  // Display value for correct answers (points, not count)
  private var correctAnswersDisplayValue: String {
    let points = correctAnswersPoints
    return points > 0 ? "+\(points)" : "0"
  }

  private var timeoutsPenalty: Int {
    levelRun.levelTimeouts * -5
  }

  // Computed property for total score including current level's positive points
  // (before completeLevel() adds them to globalScore)
  private var totalScoreWithCurrentLevel: Int {
    // levelPositivePoints already includes streak bonuses, so we don't need to
    // add them separately
    levelRun.globalScore + levelRun.levelPositivePoints
  }

  // Calculate remaining lives
  private var remainingLives: Int {
    levelRun.remainingLives
  }

  // Check if we should show bonus stat block (all levels 1-10)
  private var shouldShowBonus: Bool {
    levelRun.currentLevel >= 1 && levelRun.currentLevel <= 10
  }

  // Check if we should show missed stat block (levels 3-8)
  private var shouldShowMissed: Bool {
    levelRun.currentLevel >= 3 && levelRun.currentLevel <= 8
  }

  var body: some View {
    ZStack {
      // Global background: subtle light gradient
      LinearGradient(
        gradient: Gradient(colors: [
          Color(hex: "F5F0FF").opacity(0.3),
          Color.white,
        ]),
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 28) {
        // Top right: Remaining lives in custom gradient capsule
        HStack {
          Spacer()
          HStack(spacing: 8) {
            Image("Heart")
              .resizable()
              .scaledToFit()
              .frame(width: 24, height: 24)
            Text("\(remainingLives)")
              .font(.system(size: 20, weight: .semibold))
              .foregroundColor(.white)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(
            Capsule()
              .fill(
                LinearGradient(
                  gradient: Gradient(stops: [
                    .init(color: Color(hex: "C27AFF"), location: 0.42),
                    .init(color: Color(hex: "FF8FCA"), location: 1.0),
                  ]),
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
          )
        }
        .padding(.trailing, 20)
        .padding(.top, 10)
        .padding(.leading, 20) // Add left padding for safety margin

        // Title: Crown + "Level X Complete!" - increased by 15% again
        HStack(spacing: 8) {
          Image("Crown")
            .resizable()
            .scaledToFit()
            .frame(width: 53, height: 53)
          Text("Level \(levelRun.currentLevel) Complete!")
            .font(.system(size: 37, weight: .bold))
            .foregroundStyle(
              LinearGradient(
                gradient: Gradient(colors: [.purple, .pink]),
                startPoint: .leading,
                endPoint: .trailing
              )
            )
        }
        .padding(.horizontal, 20) // Add horizontal padding for safety margin

        // Your Score: XX / YY with 3-color gradient and adaptive sizing
        VStack(spacing: 4) {
          Text("Your Score")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(.secondary)

          HStack(spacing: 4) {
            Text("\(finalLevelScore)")
              .font(.system(size: 40, weight: .black))
              .foregroundColor(.white)
            Text("/\(levelRun.getRequiredScore())")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.white.opacity(0.9))
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 14)
          .background(
            LinearGradient(
              gradient: Gradient(stops: [
                .init(color: Color(hex: "278310"), location: 0.0),
                .init(color: Color(hex: "10DA38"), location: 0.5),
                .init(color: Color(hex: "64FB8A"), location: 1.0),
              ]),
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .cornerRadius(30)
          .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }

        // 4 Stat Blocks in a row
        HStack(spacing: 12) {
          // Cup - Correct (always shown) - show points - icon +20% more
          StatBlock(
            iconName: "Cup",
            value: correctAnswersDisplayValue,
            color: .green,
            backgroundColor: Color(hex: "F0FDF4"),
            strokeColor: Color(hex: "B9F8CF"),
            iconSize: 34.56
          )

          // Fail - Mistakes (always shown) - show penalty points - icon +20%
          // more
          StatBlock(
            iconName: "Fail",
            value: mistakesPenalty != 0 ? "\(mistakesPenalty)" : "0",
            color: .pink,
            backgroundColor: Color(hex: "FEF2F2"),
            strokeColor: Color(hex: "FFC9C9"),
            iconSize: 34.56
          )

          // Stars - Bonus (levels 3-10 only) - show bonus points - icon +20%
          if shouldShowBonus {
            StatBlock(
              iconName: "Stars",
              value: levelRun
                .getLevelStreakBonuses() > 0 ?
                "+\(levelRun.getLevelStreakBonuses())" : "0",
              color: .orange,
              backgroundColor: Color(hex: "FFF7ED"),
              strokeColor: Color(hex: "FFD6A7"),
              iconSize: 28.8
            )
          }

          // Timing - Missed (levels 3-8 only) - show penalty points - icon +20%
          if shouldShowMissed {
            StatBlock(
              iconName: "Timing",
              value: timeoutsPenalty != 0 ? "\(timeoutsPenalty)" : "0",
              color: .purple,
              backgroundColor: Color(hex: "FAF5FF"),
              strokeColor: Color(hex: "E9D4FF"),
              iconSize: 28.8
            )
          }
        }
        .padding(.horizontal, 20)

        // Total Score
        VStack(spacing: 4) {
          Text("Total Score")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.secondary)
          Text("\(totalScoreWithCurrentLevel)")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.primary)
        }

        Spacer()
          .frame(height: 10)

        // Next Level button - 3-color gradient, reduced width, text +15%
        Button(action: onNextLevel) {
          Text(levelRun.isCompleted ? "Finish Run" : "Next Level")
            .font(.system(size: 21, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(
              LinearGradient(
                gradient: Gradient(stops: [
                  .init(color: Color(hex: "2B7FFF"), location: 0.0),
                  .init(color: Color(hex: "AD46FF"), location: 0.5),
                  .init(color: Color(hex: "F6339A"), location: 1.0),
                ]),
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }

        // Back to Home — secondary exit (saves accumulated score)
        Button(action: onBackToHome) {
          Text("Back to Home")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
        }
      }
      .padding(.vertical)
      .padding(
        .horizontal,
        20
      ) // Add horizontal padding for safety margin on sides
    }
  }
}

// MARK: - Stat Block Component

struct StatBlock: View {
  let iconName: String // Image asset name
  let value: String
  let color: Color
  let backgroundColor: Color
  var strokeColor: Color? // Optional stroke color
  var iconSize: CGFloat = 24 // Default size, can be customized

  var body: some View {
    VStack(spacing: 8) {
      Image(iconName)
        .resizable()
        .scaledToFit()
        .frame(width: iconSize, height: iconSize)
      Text(value)
        .font(.system(size: 18, weight: .bold))
        .foregroundColor(color)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 16)
    .frame(height: 90) // Fixed height to ensure all blocks are exactly the same
    // size (includes padding)
    .background(
      RoundedRectangle(cornerRadius: 12)
        .fill(backgroundColor)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(
          strokeColor ?? Color.clear,
          lineWidth: strokeColor != nil ? 2 : 0
        )
    )
    .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
  }
}

// MARK: - Level Failed View (for insufficient score only)

struct LevelFailedView: View {
  @ObservedObject var levelRun: LevelRun
  let failedReason: LevelFailureReason
  let onRetry: () -> Void
  let onBackToHome: () -> Void

  // Check if we should show bonus stat block (all levels 1-10)
  private var shouldShowBonus: Bool {
    levelRun.currentLevel >= 1 && levelRun.currentLevel <= 10
  }

  // Check if we should show missed stat block (levels 3-8)
  private var shouldShowMissed: Bool {
    levelRun.currentLevel >= 3 && levelRun.currentLevel <= 8
  }

  // Calculate remaining lives
  private var remainingLives: Int {
    levelRun.remainingLives
  }

  // Computed property for total score including current level's positive points
  private var totalScoreWithCurrentLevel: Int {
    // levelPositivePoints already includes streak bonuses, so we don't need to
    // add them separately
    levelRun.globalScore + levelRun.levelPositivePoints
  }

  // Final level score (streak bonuses are already included in currentScore)
  private var finalLevelScore: Int {
    levelRun.getCurrentLevelScore()
  }

  // Calculate mistakes penalty
  private var mistakesPenalty: Int {
    // Show penalties from wrong taps (only point deductions, no life cost)
    levelRun.levelWrongTaps * -10
  }

  // Calculate timeouts penalty
  private var timeoutsPenalty: Int {
    levelRun.levelTimeouts * -5
  }

  // Display value for correct answers (points, not count)
  private var correctAnswersDisplayValue: String {
    // Calculate points from correct answers (base points only, excluding
    // bonuses)
    let points = levelRun.levelBasePoints
    return points > 0 ? "+\(points)" : "0"
  }

  var body: some View {
    ZStack {
      // Global background: subtle light gradient
      LinearGradient(
        gradient: Gradient(colors: [
          Color(hex: "F5F0FF").opacity(0.3),
          Color.white,
        ]),
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 28) {
        // Top right: Remaining lives in custom gradient capsule
        HStack {
          Spacer()
          HStack(spacing: 8) {
            Image("Heart")
              .resizable()
              .scaledToFit()
              .frame(width: 24, height: 24)
            Text("\(remainingLives)")
              .font(.system(size: 20, weight: .semibold))
              .foregroundColor(.white)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(
            Capsule()
              .fill(
                LinearGradient(
                  gradient: Gradient(stops: [
                    .init(color: Color(hex: "C27AFF"), location: 0.42),
                    .init(color: Color(hex: "FF8FCA"), location: 1.0),
                  ]),
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
          )
        }
        .padding(.trailing, 20)
        .padding(.top, 10)
        .padding(.leading, 20) // Add left padding for safety margin

        // Title: Fail icon + "Level X Failed!" - same size as Complete
        HStack(spacing: 8) {
          Image("Fail")
            .resizable()
            .scaledToFit()
            .frame(width: 53, height: 53)
          Text("Level \(levelRun.currentLevel) Failed!")
            .font(.system(size: 37, weight: .bold))
            .foregroundStyle(
              LinearGradient(
                gradient: Gradient(colors: [.purple, .pink]),
                startPoint: .leading,
                endPoint: .trailing
              )
            )
        }
        .padding(.horizontal, 20) // Add horizontal padding for safety margin

        // Your Score: XX / YY with 3-color red gradient and adaptive sizing
        VStack(spacing: 4) {
          Text("Your Score")
            .font(.system(size: 15, weight: .regular))
            .foregroundColor(.secondary)

          HStack(spacing: 4) {
            Text("\(finalLevelScore)")
              .font(.system(size: 40, weight: .black))
              .foregroundColor(.white)
            Text("/\(levelRun.getRequiredScore())")
              .font(.system(size: 12, weight: .bold))
              .foregroundColor(.white.opacity(0.9))
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 14)
          .background(
            LinearGradient(
              gradient: Gradient(stops: [
                .init(color: Color(hex: "FD0000"), location: 0.0),
                .init(color: Color(hex: "FF4B04"), location: 0.5),
                .init(color: Color(hex: "FB6466"), location: 1.0),
              ]),
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .cornerRadius(30)
          .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        }

        // 4 Stat Blocks in a row - same as Complete view
        HStack(spacing: 12) {
          // Cup - Correct (always shown) - show points - icon +20% more
          StatBlock(
            iconName: "Cup",
            value: correctAnswersDisplayValue,
            color: .green,
            backgroundColor: Color(hex: "F0FDF4"),
            strokeColor: Color(hex: "B9F8CF"),
            iconSize: 34.56
          )

          // Fail - Mistakes (always shown) - show penalty points - icon +20%
          // more
          StatBlock(
            iconName: "Fail",
            value: mistakesPenalty != 0 ? "\(mistakesPenalty)" : "0",
            color: .pink,
            backgroundColor: Color(hex: "FEF2F2"),
            strokeColor: Color(hex: "FFC9C9"),
            iconSize: 34.56
          )

          // Stars - Bonus (levels 3-10 only) - show bonus points - icon +20%
          if shouldShowBonus {
            StatBlock(
              iconName: "Stars",
              value: levelRun
                .getLevelStreakBonuses() > 0 ?
                "+\(levelRun.getLevelStreakBonuses())" : "0",
              color: .orange,
              backgroundColor: Color(hex: "FFF7ED"),
              strokeColor: Color(hex: "FFD6A7"),
              iconSize: 28.8
            )
          }

          // Timing - Missed (levels 3-8 only) - show penalty points - icon +20%
          if shouldShowMissed {
            StatBlock(
              iconName: "Timing",
              value: timeoutsPenalty != 0 ? "\(timeoutsPenalty)" : "0",
              color: .purple,
              backgroundColor: Color(hex: "FAF5FF"),
              strokeColor: Color(hex: "E9D4FF"),
              iconSize: 28.8
            )
          }
        }
        .padding(.horizontal, 20)

        // Total Score - same as Complete view
        VStack(spacing: 4) {
          Text("Total Score")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.secondary)
          Text("\(totalScoreWithCurrentLevel)")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.primary)
        }

        Spacer()
          .frame(height: 10)

        // Try Again button - same styling as Next Level button
        if failedReason == .insufficientScore {
          Button(action: onRetry) {
            Text("Try Again")
              .font(.system(size: 21, weight: .bold))
              .foregroundColor(.white)
              .padding(.horizontal, 40)
              .padding(.vertical, 14)
              .background(
                LinearGradient(
                  gradient: Gradient(stops: [
                    .init(color: Color(hex: "2B7FFF"), location: 0.0),
                    .init(color: Color(hex: "AD46FF"), location: 0.5),
                    .init(color: Color(hex: "F6339A"), location: 1.0),
                  ]),
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .cornerRadius(25)
              .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
          }

          // Back to Home — secondary exit (saves accumulated score)
          Button(action: onBackToHome) {
            Text("Back to Home")
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.secondary)
              .padding(.vertical, 8)
          }
        }
      }
      .padding(.vertical)
      .padding(
        .horizontal,
        20
      ) // Add horizontal padding for safety margin on sides
    }
  }
}

// MARK: - Final Win View (for completing level 10)

struct FinalWinView: View {
  @ObservedObject var levelRun: LevelRun
  let onPlayHarder: () -> Void
  let onSeeLeaderboard: () -> Void

  // Total score including current level's positive points
  private var totalScoreWithCurrentLevel: Int {
    levelRun.globalScore + levelRun.levelPositivePoints
  }

  var body: some View {
    ZStack {
      // Global background: subtle light gradient
      LinearGradient(
        gradient: Gradient(colors: [
          Color(hex: "F5F0FF").opacity(0.3),
          Color.white,
        ]),
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 28) {
        Spacer()
          .frame(height: 60)

        // Title: "YOU WIN!"
        Text("YOU WIN!")
          .font(.system(size: 48, weight: .bold, design: .rounded))
          .foregroundStyle(
            LinearGradient(
              gradient: Gradient(colors: [.purple, .pink]),
              startPoint: .leading,
              endPoint: .trailing
            )
          )

        // Subtitle: "Well done."
        Text("Well done.")
          .font(.system(size: 20, weight: .regular))
          .foregroundColor(.secondary)

        // Final Score
        VStack(spacing: 4) {
          Text("Final Score")
            .font(.system(size: 18, weight: .regular))
            .foregroundColor(.secondary)
          Text("\(totalScoreWithCurrentLevel)")
            .font(.system(size: 32, weight: .bold))
            .foregroundColor(.primary)
        }
        .padding(.top, 20)

        Spacer()

        // Buttons
        VStack(spacing: 16) {
          // Play Harder button - most visible with color
          Button(action: onPlayHarder) {
            Text("Play Harder")
              .font(.system(size: 21, weight: .bold))
              .foregroundColor(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 55)
              .background(
                LinearGradient(
                  gradient: Gradient(stops: [
                    .init(color: Color(hex: "2B7FFF"), location: 0.0),
                    .init(color: Color(hex: "AD46FF"), location: 0.5),
                    .init(color: Color(hex: "F6339A"), location: 1.0),
                  ]),
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .cornerRadius(27)
              .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
          }

          // See Leaderboard button - less visible
          Button(action: onSeeLeaderboard) {
            Text("See Leaderboard")
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(.primary)
              .frame(maxWidth: .infinity)
              .frame(height: 50)
              .background(
                RoundedRectangle(cornerRadius: 25)
                  .fill(Color.white)
                  .overlay(
                    RoundedRectangle(cornerRadius: 25)
                      .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                  )
              )
              .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
          }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 60)
      }
      .padding(.horizontal, 20)
    }
  }
}

// MARK: - Game Over View (for run-ending failures)

struct LevelGameOverView: View {
  @ObservedObject var levelRun: LevelRun
  let failedReason: LevelFailureReason
  let onBackToHome: () -> Void

  // Calculate remaining lives (should be 0 for game over)
  private var remainingLives: Int {
    levelRun.remainingLives
  }

  // Total score including current level's positive points
  private var totalScoreWithCurrentLevel: Int {
    levelRun.globalScore + levelRun.levelPositivePoints
  }

  // Reason for loss text
  private var lossReason: String {
    switch failedReason {
    case .maxMistakes:
      "You ran out of lives"
    case .insufficientScore:
      "" // Should not happen in LevelGameOverView
    }
  }

  var body: some View {
    ZStack {
      // Global background: subtle light gradient
      LinearGradient(
        gradient: Gradient(colors: [
          Color(hex: "F5F0FF").opacity(0.3),
          Color.white,
        ]),
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea()

      VStack(spacing: 28) {
        // Top right: Remaining lives in custom gradient capsule (should be 0) -
        // same as Complete
        HStack {
          Spacer()
          HStack(spacing: 8) {
            Image("Heart")
              .resizable()
              .scaledToFit()
              .frame(width: 24, height: 24)
            Text("\(remainingLives)")
              .font(.system(size: 20, weight: .semibold))
              .foregroundColor(.white)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(
            Capsule()
              .fill(
                LinearGradient(
                  gradient: Gradient(stops: [
                    .init(color: Color(hex: "C27AFF"), location: 0.42),
                    .init(color: Color(hex: "FF8FCA"), location: 1.0),
                  ]),
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
          )
        }
        .padding(.trailing, 20)
        .padding(.leading, 20) // Add left padding for safety margin
        .padding(.top, 10)

        // Game Over icon
        Image("Game-Over")
          .resizable()
          .scaledToFit()
          .frame(width: 60, height: 60)

        // Title: "GAME OVER" with gradient - increased by 30%
        Text("GAME OVER")
          .font(.system(size: 42, weight: .bold))
          .foregroundStyle(
            LinearGradient(
              gradient: Gradient(colors: [.purple, .pink]),
              startPoint: .leading,
              endPoint: .trailing
            )
          )

        // Reason for loss
        Text(lossReason)
          .font(.system(size: 16, weight: .regular))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 20)

        // Final Score
        VStack(spacing: 4) {
          Text("Final Score")
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.secondary)
          Text("\(totalScoreWithCurrentLevel)")
            .font(.system(size: 20, weight: .bold))
            .foregroundColor(.primary)
        }

        Spacer()
          .frame(height: 10)

        // Start a new game button - same design as Next Level button
        Button(action: onBackToHome) {
          Text("Start a new game")
            .font(.system(size: 21, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 14)
            .background(
              LinearGradient(
                gradient: Gradient(stops: [
                  .init(color: Color(hex: "2B7FFF"), location: 0.0),
                  .init(color: Color(hex: "AD46FF"), location: 0.5),
                  .init(color: Color(hex: "F6339A"), location: 1.0),
                ]),
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
        }
      }
      .padding(.vertical)
      .padding(
        .horizontal,
        20
      ) // Add horizontal padding for safety margin on sides
    }
  }
}

// MARK: - Color And Text Tile View

struct ColorAndTextTile: View {
  let tile: Tile
  let action: () -> Void

  // Helper to determine text color for contrast
  private func textColor(for backgroundColor: Color) -> Color {
    // Simple luminance-based contrast
    // Red, blue, green backgrounds -> white text
    // Yellow background -> black text
    if backgroundColor == .yellow {
      return .black
    }
    return .white
  }

  var body: some View {
    Button(action: action) {
      ZStack {
        RoundedRectangle(cornerRadius: 20)
          .fill(tile.backgroundColor)
          .frame(width: 120, height: 120)
          .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)

        Text(tile.textLabel.uppercased())
          .font(.system(size: 18, weight: .semibold, design: .rounded))
          .foregroundColor(textColor(for: tile.backgroundColor))
          .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
      }
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// MARK: - Color Extension for Hex

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
      (a, r, g, b) = (
        255,
        (int >> 8) * 17,
        (int >> 4 & 0xF) * 17,
        (int & 0xF) * 17
      )
    case 6: // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

#Preview {
  LevelGameView(levelRun: LevelRun())
}
