//
//  GameView.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import SwiftUI

enum GameEndReason {
    case timeUp
    case tooManyMistakes
    case scoreBelowZero
}

struct ScoringLedger {
    var correctCount: Int = 0
    var incorrectCount: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var bonusTriggers: Int = 0
    
    var bonusPoints: Int {
        bonusTriggers * 5
    }
    
    var baseScore: Int {
        (correctCount * 10) + (incorrectCount * -5)
    }
    
    var finalScore: Int {
        baseScore + bonusPoints
    }
    
    mutating func reset() {
        correctCount = 0
        incorrectCount = 0
        currentStreak = 0
        bestStreak = 0
        bonusTriggers = 0
    }
}

struct GameView: View {
    let selectedDifficulty: Difficulty
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customizationStore = CustomizationStore.shared
    
    // Game state
    @State private var scoringLedger = ScoringLedger()
    @State private var mistakes = 0
    @State private var announcedColor: Color = .red
    @State private var tiles: [Color] = [] // For Easy/Normal modes
    @State private var hardModeTiles: [Tile] = [] // For Hard mode
    @State private var previousTiles: [Color] = []
    @State private var previousHardModeTiles: [Tile] = []
    @State private var showingErrorFlash = false
    @State private var isGameActive = false
    
    // Global timer state
    @State private var timeRemaining = 30.0
    @State private var gameTimer: Timer?
    @State private var isGameSessionActive = false
    @State private var backgroundTime: Date?
    
    // Round timer state (for Normal mode)
    @State private var roundTimeRemaining = 1.5
    @State private var roundTimer: Timer?
    @State private var isRoundTimerActive = false
    
    // Game over state
    @State private var isGameOver = false
    @State private var gameEndReason: GameEndReason?
    @State private var isNewBestScore = false
    
    // Color repeat tracking
    @State private var recentAnnouncedColors: [Color] = []
    
    // Services
    @State private var speechService = SpeechService()
    private let hapticsService = HapticsService.shared
    @StateObject private var highScoreStore = HighScoreStore.shared
    
    // Stored property for max mistakes based on difficulty and settings
    @State private var maxMistakes: Int = 3
    
    // Color palette
    private let colorPalette: [Color] = [.red, .blue, .green, .yellow]
    private let colorNames = ["red", "blue", "green", "yellow"]
    
    var body: some View {
        NavigationView {
            ZStack {
                if isGameOver {
                    // Game Over Screen
                    GameOverView(
                        score: scoringLedger.finalScore,
                        mistakes: mistakes,
                        correctAnswers: scoringLedger.correctCount,
                        incorrectAnswers: scoringLedger.incorrectCount,
                        maxStreak: scoringLedger.bestStreak,
                        bonusTriggers: scoringLedger.bonusTriggers,
                        endReason: gameEndReason,
                        isNewBestScore: isNewBestScore,
                        onBackToHome: {
                            dismiss()
                        },
                        onPlayAgain: {
                            resetGame()
                        }
                    )
                } else {
                    // Active Game Screen
                    VStack(spacing: 30) {
                        // Header with score and global timer
                        VStack(spacing: 8) {
                            // Top row: Score and Back button
                            HStack {
                                Text("Score: \(scoringLedger.finalScore)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button("Back") {
                                    endGameSession()
                                    dismiss()
                                }
                                .font(.title3)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.2))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                            }
                            
                            // Bottom row: Time and Mistakes
                            HStack {
                                Text("Time: \(Int(timeRemaining))s")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(timeRemaining <= 5 ? .red : .primary)
                                
                                Spacer()
                                
                                Text("Mistakes: \(mistakes)/\(maxMistakes)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(mistakes > maxMistakes ? .red : .primary)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        // Round Progress Bar (Normal mode only)
                        if selectedDifficulty == .normal {
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
                                            .fill(roundTimeRemaining > 0.5 ? Color.green : Color.red)
                                            .frame(width: geometry.size.width * (roundTimeRemaining / 1.5), height: 8)
                                            .animation(.linear(duration: 0.1), value: roundTimeRemaining)
                                    }
                                }
                                .frame(height: 8)
                                .padding(.horizontal, 40)
                            }
                            .padding(.bottom, 10)
                        }
                        
                        // 2x2 Grid
                        VStack(spacing: 20) {
                            HStack(spacing: 20) {
                                if selectedDifficulty == .hard {
                                    HardModeTile(tile: hardModeTiles.count > 0 ? hardModeTiles[0] : Tile(backgroundColor: .gray, textLabel: "?"), action: { handleTileTap(0) })
                                    HardModeTile(tile: hardModeTiles.count > 1 ? hardModeTiles[1] : Tile(backgroundColor: .gray, textLabel: "?"), action: { handleTileTap(1) })
                                } else {
                                    ColorTile(color: tiles.count > 0 ? tiles[0] : .gray, action: { handleTileTap(0) })
                                    ColorTile(color: tiles.count > 1 ? tiles[1] : .gray, action: { handleTileTap(1) })
                                }
                            }
                            HStack(spacing: 20) {
                                if selectedDifficulty == .hard {
                                    HardModeTile(tile: hardModeTiles.count > 2 ? hardModeTiles[2] : Tile(backgroundColor: .gray, textLabel: "?"), action: { handleTileTap(2) })
                                    HardModeTile(tile: hardModeTiles.count > 3 ? hardModeTiles[3] : Tile(backgroundColor: .gray, textLabel: "?"), action: { handleTileTap(3) })
                                } else {
                                    ColorTile(color: tiles.count > 2 ? tiles[2] : .gray, action: { handleTileTap(2) })
                                    ColorTile(color: tiles.count > 3 ? tiles[3] : .gray, action: { handleTileTap(3) })
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    
                    // Error flash overlay
                    if showingErrorFlash {
                        Color.red.opacity(0.3)
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                startGameSession()
                setupBackgroundNotifications()
            }
            .onDisappear {
                endGameSession()
                removeBackgroundNotifications()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func handleTileTap(_ index: Int) {
        guard isGameActive, isGameSessionActive, !isGameOver else { return }
        
        // End round timer immediately when tile is tapped (prevents double-counting)
        endRoundTimer()
        
        let isCorrect: Bool
        
        if selectedDifficulty == .hard {
            guard index < hardModeTiles.count else { return }
            let tappedTile = hardModeTiles[index]
            isCorrect = tappedTile.isValidHard(announcedColor: announcedColor)
        } else {
            guard index < tiles.count else { return }
            let tappedColor = tiles[index]
            isCorrect = tappedColor != announcedColor
        }
        
        if isCorrect {
            // Correct tap - update ledger
            scoringLedger.correctCount += 1
            scoringLedger.currentStreak += 1
            
            // Check for streak bonus (every 5 consecutive correct)
            if scoringLedger.currentStreak % 5 == 0 {
                scoringLedger.bonusTriggers += 1
            }
            
            // Update best streak
            scoringLedger.bestStreak = max(scoringLedger.bestStreak, scoringLedger.currentStreak)
            
            let tappedDescription = selectedDifficulty == .hard ? 
                "\(hardModeTiles[index].textLabel) on \(colorName(for: hardModeTiles[index].backgroundColor))" :
                colorName(for: tiles[index])
            print("correct: \(tappedDescription) - Score: \(scoringLedger.finalScore)")
            hapticsService.lightImpact()
        } else {
            // Incorrect tap - update ledger
            scoringLedger.incorrectCount += 1
            scoringLedger.currentStreak = 0 // Reset streak on incorrect
            mistakes += 1
            
            let tappedDescription = selectedDifficulty == .hard ? 
                "\(hardModeTiles[index].textLabel) on \(colorName(for: hardModeTiles[index].backgroundColor))" :
                colorName(for: tiles[index])
            print("wrong: \(tappedDescription) - Score: \(scoringLedger.finalScore)")
            hapticsService.heavyImpact()
            showErrorFlash()
        }
        
        // Check game over conditions in order (using finalScore from ledger)
        if scoringLedger.finalScore < 0 {
            endGameWithReason(.scoreBelowZero)
            return
        }
        
        if mistakes > maxMistakes {
            endGameWithReason(.tooManyMistakes)
            return
        }
        
        // Wait 300ms then start next round (purely visual/UX delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Only start new round if game session is still active and not game over
            if self.isGameSessionActive && !self.isGameOver {
                self.startNewRound()
            }
        }
    }
    
    private func startNewRound() {
        isGameActive = false
        
        // Store previous tiles for comparison
        if selectedDifficulty == .hard {
            previousHardModeTiles = hardModeTiles
        } else {
            previousTiles = tiles
        }
        
        // Select random announced color with repeat prevention
        announcedColor = selectAnnouncedColor()
        
        // Update recent colors tracking
        updateRecentColors(announcedColor)
        
        // Speak the announced color
        speechService.speak(colorName(for: announcedColor))
        
        // Build valid grid based on difficulty
        if selectedDifficulty == .hard {
            hardModeTiles = buildHardModeGrid()
            // Debug logging for Hard mode
            let tileDescriptions = hardModeTiles.map { "\($0.textLabel) on \(colorName(for: $0.backgroundColor))" }
            print("New Hard mode grid: [\(tileDescriptions.joined(separator: ", "))]")
        } else {
            tiles = buildValidGrid()
            // Debug logging for Easy/Normal modes
            let tileNames = tiles.map { colorName(for: $0) }
            print("New round grid: [\(tileNames.joined(separator: ", "))]")
        }
        
        // Enable game after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isGameActive = true
            
            // Start round timer for Normal mode
            if selectedDifficulty == .normal {
                startRoundTimer()
            }
        }
    }
    
    private func buildValidGrid() -> [Color] {
        var attempts = 0
        let maxAttempts = 10 // Prevent infinite loops
        
        while attempts < maxAttempts {
            var grid: [Color] = []
            
            // Step 1: Add the announced color at least once
            grid.append(announcedColor)
            
            // Step 2: Add at least one different color from the palette
            let nonAnnouncedColors = colorPalette.filter { $0 != announcedColor }
            if let differentColor = nonAnnouncedColors.randomElement() {
                grid.append(differentColor)
            }
            
            // Step 3: Fill remaining 2 slots randomly from all colors in the palette
            while grid.count < 4 {
                grid.append(colorPalette.randomElement() ?? .red)
            }
            
            // Step 4: Shuffle the grid to randomize positions
            let shuffledGrid = grid.shuffled()
            
            // Step 5: Check if this grid is identical to the previous round
            if shuffledGrid != previousTiles {
                return shuffledGrid
            }
            
            // If identical, try again with a fresh randomization
            attempts += 1
            if attempts <= 3 { // Only log first few attempts to avoid spam
                print("Prevented identical grid, retrying... (attempt \(attempts))")
            }
        }
        
        // Fallback: if we can't find a different grid after max attempts,
        // return a shuffled version anyway (should be very rare)
        var fallbackGrid: [Color] = [announcedColor]
        let nonAnnouncedColors = colorPalette.filter { $0 != announcedColor }
        if let differentColor = nonAnnouncedColors.randomElement() {
            fallbackGrid.append(differentColor)
        }
        while fallbackGrid.count < 4 {
            fallbackGrid.append(colorPalette.randomElement() ?? .red)
        }
        
        return fallbackGrid.shuffled()
    }
    
    private func buildHardModeGrid() -> [Tile] {
        var attempts = 0
        let maxAttempts = 30 // Increased attempts for more complex constraints
        
        while attempts < maxAttempts {
            // Step A: announcedColor is already set in startNewRound()
            
            // Step B: Generate 4 tiles with enhanced constraints
            var tiles: [Tile] = []
            
            // Ensure at least one tile has background matching announced color
            let backgroundMatchTile = Tile(
                backgroundColor: announcedColor,
                textLabel: colorNames.first { $0 != colorName(for: announcedColor) }?.uppercased() ?? "BLUE"
            )
            tiles.append(backgroundMatchTile)
            
            // Ensure at least one tile has label matching announced color
            let labelMatchTile = Tile(
                backgroundColor: colorPalette.first { $0 != announcedColor } ?? .blue,
                textLabel: colorName(for: announcedColor).uppercased()
            )
            tiles.append(labelMatchTile)
            
            // Fill remaining 2 slots with random tiles (background ≠ label constraint)
            for _ in 0..<2 {
                let backgroundColor = colorPalette.randomElement() ?? .red
                let availableLabels = colorNames.filter { $0 != colorName(for: backgroundColor) }
                let textLabel = availableLabels.randomElement() ?? "red"
                tiles.append(Tile(backgroundColor: backgroundColor, textLabel: textLabel.uppercased()))
            }
            
            // Step C: Compute validCount using the single validator
            let validCount = tiles.filter { $0.isValidHard(announcedColor: announcedColor) }.count
            
            // Step D: Accept only if validCount is 1 or 2
            if validCount >= 1 && validCount <= 2 {
                // Check if this grid is different from the previous round
                if tiles != previousHardModeTiles {
                    // Step E: Shuffle tile order right before display
                    return tiles.shuffled()
                }
            }
            
            attempts += 1
        }
        
        // Fallback: Force 1-2 valid tiles deterministically with new constraints
        return buildDeterministicHardModeGrid()
    }
    
    private func buildDeterministicHardModeGrid() -> [Tile] {
        var tiles: [Tile] = []
        
        // Create tiles that guarantee 1-2 valid answers with new constraints
        // Strategy: Ensure background match + label match + 1-2 valid tiles
        
        // Required: At least one tile with background matching announced color
        let backgroundMatchTile = Tile(
            backgroundColor: announcedColor,
            textLabel: colorNames.first { $0 != colorName(for: announcedColor) }?.uppercased() ?? "BLUE"
        )
        tiles.append(backgroundMatchTile)
        
        // Required: At least one tile with label matching announced color
        let labelMatchTile = Tile(
            backgroundColor: colorPalette.first { $0 != announcedColor } ?? .blue,
            textLabel: colorName(for: announcedColor).uppercased()
        )
        tiles.append(labelMatchTile)
        
        // Valid tile: different background and label from announced
        let validColor = colorPalette.first { $0 != announcedColor && $0 != tiles[1].backgroundColor } ?? .green
        let validLabel = colorNames.first { $0 != colorName(for: validColor) && $0 != colorName(for: announcedColor) } ?? "yellow"
        tiles.append(Tile(backgroundColor: validColor, textLabel: validLabel.uppercased()))
        
        // Fourth tile: another valid tile or invalid tile to maintain 1-2 valid count
        let fourthColor = colorPalette.first { $0 != announcedColor && $0 != validColor && $0 != tiles[1].backgroundColor } ?? .yellow
        let fourthLabel = colorNames.first { $0 != colorName(for: fourthColor) && $0 != colorName(for: announcedColor) } ?? "red"
        tiles.append(Tile(backgroundColor: fourthColor, textLabel: fourthLabel.uppercased()))
        
        return tiles.shuffled()
    }
    
    private func showErrorFlash() {
        withAnimation(.easeInOut(duration: 0.1)) {
            showingErrorFlash = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
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
    
    // MARK: - Color Repeat Prevention
    
    private func selectAnnouncedColor() -> Color {
        // If we have less than 2 recent colors, pick randomly from all colors
        guard recentAnnouncedColors.count >= 2 else {
            return colorPalette.randomElement() ?? .red
        }
        
        // Check if the last two colors are the same
        let lastTwoColors = Array(recentAnnouncedColors.suffix(2))
        if lastTwoColors[0] == lastTwoColors[1] {
            // Last two colors are identical, exclude that color from selection
            let excludedColor = lastTwoColors[0]
            let availableColors = colorPalette.filter { $0 != excludedColor }
            return availableColors.randomElement() ?? .red
        }
        
        // Last two colors are different, pick randomly from all colors
        return colorPalette.randomElement() ?? .red
    }
    
    private func updateRecentColors(_ color: Color) {
        recentAnnouncedColors.append(color)
        
        // Keep only the last 2 colors to prevent memory buildup
        if recentAnnouncedColors.count > 2 {
            recentAnnouncedColors.removeFirst()
        }
    }
    
    // MARK: - Timer Management
    
    private func startGameSession() {
        isGameSessionActive = true
        
        // Use custom duration and max mistakes for Easy mode, defaults for others
        if selectedDifficulty == .easy {
            let storedDuration = customizationStore.getEasyDuration()
            let storedMaxMistakes = customizationStore.getEasyMaxMistakes()
            
            // Safety checks for corrupted settings
            timeRemaining = Double(storedDuration > 0 ? storedDuration : 30)
            // If maxMistakes is 0, it means sudden death mode is explicitly set
            // If it's negative or corrupted, default to 3
            maxMistakes = storedMaxMistakes >= 0 ? storedMaxMistakes : 3
        } else {
            timeRemaining = 30.0
            maxMistakes = 3
        }
        
        // Start global timer
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 0.1
            } else {
                self.endGameWithReason(.timeUp)
            }
        }
        
        // Start first round
        startNewRound()
    }
    
    private func endGameSession() {
        isGameSessionActive = false
        isGameActive = false
        gameTimer?.invalidate()
        gameTimer = nil
        
        // Also end round timer if active
        endRoundTimer()
        
        print("Game session ended. Final score: \(scoringLedger.finalScore), Mistakes: \(mistakes)")
    }
    
    // MARK: - Round Timer Management (Normal mode)
    
    private func startRoundTimer() {
        // Only start round timer for Normal mode
        guard selectedDifficulty == .normal else { return }
        
        // Cancel any existing round timer
        endRoundTimer()
        
        roundTimeRemaining = 1.5
        isRoundTimerActive = true
        
        roundTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
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
        // Only process timeout if game is still active and not already game over
        guard isGameActive, isGameSessionActive, !isGameOver else { return }
        
        // Register as incorrect answer
        scoringLedger.incorrectCount += 1
        scoringLedger.currentStreak = 0 // Reset streak on timeout
        mistakes += 1
        
        print("Round timeout - Score: \(scoringLedger.finalScore)")
        hapticsService.heavyImpact()
        showErrorFlash()
        
        // End the round timer
        endRoundTimer()
        
        // Check game over conditions
        if scoringLedger.finalScore < 0 {
            endGameWithReason(.scoreBelowZero)
            return
        }
        
        if mistakes > maxMistakes {
            endGameWithReason(.tooManyMistakes)
            return
        }
        
        // Start next round after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.isGameSessionActive && !self.isGameOver {
                self.startNewRound()
            }
        }
    }
    
    private func endGameWithReason(_ reason: GameEndReason) {
        gameEndReason = reason
        isGameOver = true
        
        // Check for new best score
        isNewBestScore = highScoreStore.updateBestScore(for: selectedDifficulty, score: scoringLedger.finalScore)
        
        // Save score to leaderboard with metadata for Easy mode
        if selectedDifficulty == .easy {
            LeaderboardStore.shared.addScore(
                scoringLedger.finalScore, 
                for: selectedDifficulty,
                durationSeconds: customizationStore.getEasyDuration(),
                maxMistakes: customizationStore.getEasyMaxMistakes()
            )
        } else {
            LeaderboardStore.shared.addScore(scoringLedger.finalScore, for: selectedDifficulty)
        }
        
        endGameSession()
        
        print("Game over: \(reason), Final score: \(scoringLedger.finalScore), Mistakes: \(mistakes), New best: \(isNewBestScore)")
    }
    
    private func resetGame() {
        // Reset all game state
        scoringLedger.reset()
        mistakes = 0
        
        // Use custom duration and max mistakes for Easy mode, defaults for others
        if selectedDifficulty == .easy {
            timeRemaining = Double(customizationStore.getEasyDuration())
            maxMistakes = customizationStore.getEasyMaxMistakes()
        } else {
            timeRemaining = 30.0
            maxMistakes = 3
        }
        tiles = []
        hardModeTiles = []
        previousTiles = []
        previousHardModeTiles = []
        isGameOver = false
        gameEndReason = nil
        isNewBestScore = false
        recentAnnouncedColors = []
        
        // Reset round timer state
        roundTimeRemaining = 1.5
        endRoundTimer()
        
        // Start new game session
        startGameSession()
    }
    
    // MARK: - Background/Foreground Handling
    
    private func setupBackgroundNotifications() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.pauseTimer()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.resumeTimer()
        }
    }
    
    private func removeBackgroundNotifications() {
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    private func pauseTimer() {
        guard isGameSessionActive else { return }
        backgroundTime = Date()
        gameTimer?.invalidate()
        gameTimer = nil
        
        // Also pause round timer if active
        if isRoundTimerActive {
            roundTimer?.invalidate()
            roundTimer = nil
        }
    }
    
    private func resumeTimer() {
        guard isGameSessionActive, let backgroundTime = backgroundTime else { return }
        
        // Calculate elapsed time while backgrounded
        let elapsedTime = Date().timeIntervalSince(backgroundTime)
        timeRemaining -= elapsedTime
        
        // Check if time expired while backgrounded
        if timeRemaining <= 0 {
            endGameWithReason(.timeUp)
            return
        }
        
        // Resume timer
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 0.1
            } else {
                self.endGameWithReason(.timeUp)
            }
        }
        
        // Resume round timer if it was active and game is still active
        if isRoundTimerActive && isGameActive && !isGameOver {
            startRoundTimer()
        }
        
        self.backgroundTime = nil
    }
}

struct GameOverView: View {
    let score: Int
    let mistakes: Int
    let correctAnswers: Int
    let incorrectAnswers: Int
    let maxStreak: Int
    let bonusTriggers: Int
    let endReason: GameEndReason?
    let isNewBestScore: Bool
    let onBackToHome: () -> Void
    let onPlayAgain: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                if isSessionComplete {
                    // Session Complete - Detailed Results
                    sessionCompleteView
                } else {
                    // Game Over - Simplified View
                    gameOverView
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Session Complete View (Detailed Results)
    private var sessionCompleteView: some View {
        VStack(spacing: 25) {
            // Header
            VStack(spacing: 10) {
                Text("Session Complete")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.blue)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            
            // Final Score Card
            VStack(spacing: 15) {
                Text("Final Score")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("\(score)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Score Breakdown
            VStack(spacing: 12) {
                Text("Score Breakdown")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Correct Answers
                BreakdownTile(
                    title: "Correct (×10)",
                    count: correctAnswers,
                    points: correctAnswers * 10,
                    color: .green
                )
                
                // Incorrect Answers
                BreakdownTile(
                    title: "Incorrect (×−5)",
                    count: incorrectAnswers,
                    points: -(incorrectAnswers * 5),
                    color: .red
                )
                
                // Streak Bonus
                BreakdownTile(
                    title: "Streak Bonus (×+5 every 5)",
                    count: bonusTriggers,
                    points: bonusTriggers * 5,
                    color: .orange
                )
            }
            
            // High Score Badge (if applicable)
            if isNewHighScore {
                HStack {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("New High Score!")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.yellow.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.yellow, lineWidth: 2)
                        )
                )
            }
            
            // Action Buttons
            actionButtons
        }
    }
    
    // MARK: - Game Over View (Simplified)
    private var gameOverView: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 15) {
                Text("GAME OVER")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                
                Text(gameOverReason)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            // Final Score (smaller)
            VStack(spacing: 10) {
                Text("Final Score")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                Text("\(score)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 30)
            .background(
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            )
            
            Spacer()
            
            // Action Buttons
            actionButtons
        }
    }
    
    // MARK: - Action Buttons (Shared)
    private var actionButtons: some View {
        VStack(spacing: 15) {
            Button(action: onPlayAgain) {
                Text("Play Again")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            
            Button(action: onBackToHome) {
                Text("Back to Home")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 45)
                    .background(
                        RoundedRectangle(cornerRadius: 22)
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.top, 10)
    }
    
    private var isSessionComplete: Bool {
        return endReason == .timeUp
    }
    
    private var gameOverReason: String {
        switch endReason {
        case .tooManyMistakes:
            return "You reached the maximum mistakes allowed."
        case .scoreBelowZero:
            return "Score fell below zero."
        default:
            return "Game ended."
        }
    }
    
    private var isNewHighScore: Bool {
        return isNewBestScore
    }
}

struct BreakdownTile: View {
    let title: String
    let count: Int
    let points: Int
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(count) → \(points >= 0 ? "+" : "")\(points)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
            
            Spacer()
            
            // Visual indicator
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text("\(count)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct HardModeTile: View {
    let tile: Tile
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 20)
                .fill(tile.backgroundColor)
                .frame(width: 120, height: 120)
                .overlay(
                    Text(tile.textLabel)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 1, x: 0, y: 1)
                )
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ColorTile: View {
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 20)
                .fill(color)
                .frame(width: 120, height: 120)
                .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    GameView(selectedDifficulty: .easy)
}
