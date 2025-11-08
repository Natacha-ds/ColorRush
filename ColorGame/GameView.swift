//
//  GameView.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif os(macOS)
import AppKit
#endif

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
    
    // Confusion timer state (for Hard mode)
    @State private var confusionTimeRemaining = 1.8
    @State private var confusionTimer: Timer?
    @State private var isConfusionTimerActive = false
    
    // Game over state
    @State private var isGameOver = false
    @State private var gameEndReason: GameEndReason?
    @State private var isNewBestScore = false
    
    // Tap tracking for Easy and Normal modes (prevent repetitive tapping)
    @State private var tapCounts: [Int] = [0, 0, 0, 0] // Track taps per position (0-3)
    @State private var consecutiveTapsOnSamePosition = 0
    @State private var lastTappedPosition = -1
    
    // Color repeat tracking
    @State private var recentAnnouncedColors: [Color] = []
    
    // Services
    @State private var speechService = SpeechService()
    private let hapticsService = HapticsService.shared
    @StateObject private var highScoreStore = HighScoreStore.shared
    
    // Stored property for max mistakes based on difficulty and settings
    @State private var maxMistakes: Int = 2
    
    // Color palette
    private let colorPalette: [Color] = [.red, .blue, .green, .yellow]
    private let colorNames = ["red", "blue", "green", "yellow"]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Full screen background for all views
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.purple.opacity(0.1),
                        Color.pink.opacity(0.05),
                        Color.white
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea(.all)
                
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
                    VStack(spacing: 0) {
                        // Top header with back button
                        HStack {
                            Button(action: {
                                endGameSession()
                                dismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.primary)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.white.opacity(0.8))
                                            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                                    )
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Score and Mistakes row
                        HStack {
                            Text("🏆 Score: \(scoringLedger.finalScore)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("💔 Mistakes: \(mistakes)/\(maxMistakes)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(mistakes > maxMistakes ? .red : .primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        Spacer()
                        
                        // Large centered timer
                        VStack(spacing: 8) {
                            Text("\(Int(timeRemaining))s")
                                .font(.system(size: 64, weight: .bold, design: .rounded))
                                .foregroundColor(timeRemaining <= 5 ? .red : .primary)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                            
                            Text("Time Remaining")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        .padding(.bottom, 30)
                        
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
                            .padding(.bottom, 20)
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
                }
            }
            #if !os(macOS)
            .navigationBarHidden(true)
            #endif
            .onAppear {
                startGameSession()
                setupBackgroundNotifications()
            }
            .onDisappear {
                endGameSession()
                removeBackgroundNotifications()
            }
        }
        #if !os(macOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
    
    private func handleTileTap(_ index: Int) {
        guard isGameActive, isGameSessionActive, !isGameOver else { return }
        
        // End round timer immediately when tile is tapped (prevents double-counting)
        endRoundTimer()
        
        // End confusion timer immediately when tile is tapped (Hard mode)
        endConfusionTimer()
        
        let isCorrect: Bool
        
        if selectedDifficulty == .hard {
            guard index < hardModeTiles.count else { return }
            let tappedTile = hardModeTiles[index]
            isCorrect = tappedTile.isValidHard(announcedColor: announcedColor)
        } else {
            guard index < tiles.count else { return }
            let tappedColor = tiles[index]
            isCorrect = tappedColor != announcedColor
            
            // Track tap patterns for Easy and Normal modes (prevent repetitive tapping)
            trackTapPattern(index: index)
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
    
    // MARK: - Tap Pattern Tracking (Easy and Normal modes)
    private func trackTapPattern(index: Int) {
        // Only track for Easy and Normal modes
        guard selectedDifficulty != .hard else { return }
        
        // Update tap counts
        tapCounts[index] += 1
        
        // Track consecutive taps on same position
        if index == lastTappedPosition {
            consecutiveTapsOnSamePosition += 1
        } else {
            consecutiveTapsOnSamePosition = 1
            lastTappedPosition = index
        }
        
        print("Tap tracking - Position \(index): \(tapCounts[index]) total, \(consecutiveTapsOnSamePosition) consecutive")
    }
    
    private func shouldPreventRepetitiveTapping() -> Bool {
        // Only apply to Easy and Normal modes
        guard selectedDifficulty != .hard else { return false }
        
        // Check if same position tapped 3 times in a row
        return consecutiveTapsOnSamePosition >= 3
    }
    
    private func resetTapTracking() {
        tapCounts = [0, 0, 0, 0]
        consecutiveTapsOnSamePosition = 0
        lastTappedPosition = -1
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
            // Start confusion timer for Hard mode
            else if selectedDifficulty == .hard {
                startConfusionTimer()
            }
        }
    }
    
    private func buildValidGrid() -> [Color] {
        var attempts = 0
        let maxAttempts = 10 // Prevent infinite loops
        
        // Check if we need to prevent repetitive tapping
        let shouldPreventRepetitive = shouldPreventRepetitiveTapping()
        let targetPosition = shouldPreventRepetitive ? lastTappedPosition : -1
        
        if shouldPreventRepetitive {
            print("Anti-repetitive tapping: Placing announced color at position \(targetPosition)")
        }
        
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
            var shuffledGrid = grid.shuffled()
            
            // Step 5: Anti-repetitive tapping logic
            if shouldPreventRepetitive && targetPosition >= 0 && targetPosition < 4 {
                // Ensure the announced color is at the frequently tapped position
                if shuffledGrid[targetPosition] != announcedColor {
                    // Find where the announced color is and swap it
                    if let announcedIndex = shuffledGrid.firstIndex(of: announcedColor) {
                        shuffledGrid.swapAt(announcedIndex, targetPosition)
                    }
                }
            }
            
            // Step 6: Check if this grid is identical to the previous round
            if shuffledGrid != previousTiles {
                // Reset tap tracking after successful intervention
                if shouldPreventRepetitive {
                    resetTapTracking()
                    print("Reset tap tracking after anti-repetitive intervention")
                }
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
        
        var finalGrid = fallbackGrid.shuffled()
        
        // Apply anti-repetitive logic to fallback as well
        if shouldPreventRepetitive && targetPosition >= 0 && targetPosition < 4 {
            if finalGrid[targetPosition] != announcedColor {
                if let announcedIndex = finalGrid.firstIndex(of: announcedColor) {
                    finalGrid.swapAt(announcedIndex, targetPosition)
                }
            }
            resetTapTracking()
        }
        
        return finalGrid
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
        
        // Use custom settings based on difficulty
        if selectedDifficulty == .easy {
            let storedDuration = customizationStore.getEasyDuration()
            let storedMaxMistakes = customizationStore.getEasyMaxMistakes()
            
            // Safety checks for corrupted settings
            timeRemaining = Double(storedDuration > 0 ? storedDuration : 30)
            // If maxMistakes is 0, it means sudden death mode is explicitly set
            // If it's negative or corrupted, default to 3
                    maxMistakes = storedMaxMistakes >= 0 ? storedMaxMistakes : 2
        } else if selectedDifficulty == .normal {
            let storedRoundTimeout = customizationStore.getNormalRoundTimeout()
            let storedMaxMistakes = customizationStore.getNormalMaxMistakes()
            
            // Use custom round timeout and max mistakes for Normal mode
            roundTimeRemaining = storedRoundTimeout > 0 ? storedRoundTimeout : 1.5
                    maxMistakes = storedMaxMistakes >= 0 ? storedMaxMistakes : 2
            timeRemaining = 30.0 // Global timer stays 30s for Normal mode
            
        } else if selectedDifficulty == .hard {
            let storedConfusionSpeed = customizationStore.getHardConfusionSpeed()
            let storedMaxMistakes = customizationStore.getHardMaxMistakes()
            
            // Use custom confusion speed and max mistakes for Hard mode
            confusionTimeRemaining = storedConfusionSpeed > 0 ? storedConfusionSpeed : 1.8
                    maxMistakes = storedMaxMistakes >= 0 ? storedMaxMistakes : 2
            timeRemaining = 30.0 // Global timer stays 30s for Hard mode
        } else {
            // Fallback - use defaults
            timeRemaining = 30.0
                    maxMistakes = 2
            roundTimeRemaining = 1.5
            confusionTimeRemaining = 1.8
        }
        
        // Reset tap tracking for new game session
        resetTapTracking()
        
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
        
        // Also end confusion timer if active
        endConfusionTimer()
        
        print("Game session ended. Final score: \(scoringLedger.finalScore), Mistakes: \(mistakes)")
    }
    
    // MARK: - Round Timer Management (Normal mode)
    
    private func startRoundTimer() {
        // Only start round timer for Normal mode
        guard selectedDifficulty == .normal else { return }
        
        // Cancel any existing round timer
        endRoundTimer()
        
        // Use custom round timeout from settings
        let storedRoundTimeout = customizationStore.getNormalRoundTimeout()
        roundTimeRemaining = storedRoundTimeout > 0 ? storedRoundTimeout : 1.5
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
    
    // MARK: - Confusion Timer (Hard mode)
    
    private func startConfusionTimer() {
        // Only start confusion timer for Hard mode
        guard selectedDifficulty == .hard else { return }
        
        // Cancel any existing confusion timer
        endConfusionTimer()
        
        // Use custom confusion speed from settings
        let storedConfusionSpeed = customizationStore.getHardConfusionSpeed()
        confusionTimeRemaining = storedConfusionSpeed > 0 ? storedConfusionSpeed : 1.8
        isConfusionTimerActive = true
        
        confusionTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.confusionTimeRemaining -= 0.1
            
            if self.confusionTimeRemaining <= 0 {
                self.handleConfusionTimeout()
            }
        }
    }
    
    private func endConfusionTimer() {
        confusionTimer?.invalidate()
        confusionTimer = nil
        isConfusionTimerActive = false
    }
    
    private func handleConfusionTimeout() {
        // Only process confusion timeout if game is still active and not already game over
        guard isGameActive, isGameSessionActive, !isGameOver else { return }
        
        // Refresh the grid while keeping the same announced color
        if selectedDifficulty == .hard {
            // Store previous tiles for comparison
            previousHardModeTiles = hardModeTiles
            
            // Build new grid with same announced color
            hardModeTiles = buildHardModeGrid()
            
            // Debug logging for Hard mode refresh
            let tileDescriptions = hardModeTiles.map { "\($0.textLabel) on \(colorName(for: $0.backgroundColor))" }
            print("Confusion refresh - New Hard mode grid: [\(tileDescriptions.joined(separator: ", "))]")
            
            // Optional: Play haptic feedback to signal refresh
            hapticsService.lightImpact()
        }
        
        // End the confusion timer
        endConfusionTimer()
        
        // Start new confusion timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.isGameSessionActive && !self.isGameOver && self.isGameActive {
                self.startConfusionTimer()
            }
        }
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
        
        // Save score to leaderboard (map Difficulty to MistakeTolerance)
        let mistakeTolerance: MistakeTolerance
        switch selectedDifficulty {
        case .easy:
            mistakeTolerance = .easy
        case .normal:
            mistakeTolerance = .normal
        case .hard:
            mistakeTolerance = .hard
        }
        LeaderboardStore.shared.addScore(scoringLedger.finalScore, for: mistakeTolerance)
        
        endGameSession()
        
        print("Game over: \(reason), Final score: \(scoringLedger.finalScore), Mistakes: \(mistakes), New best: \(isNewBestScore)")
    }
    
    private func resetGame() {
        // Reset all game state
        scoringLedger.reset()
        mistakes = 0
        
        // Use custom settings based on difficulty
        if selectedDifficulty == .easy {
            timeRemaining = Double(customizationStore.getEasyDuration())
            maxMistakes = customizationStore.getEasyMaxMistakes()
        } else if selectedDifficulty == .normal {
            roundTimeRemaining = customizationStore.getNormalRoundTimeout()
            maxMistakes = customizationStore.getNormalMaxMistakes()
            timeRemaining = 30.0
        } else if selectedDifficulty == .hard {
            confusionTimeRemaining = customizationStore.getHardConfusionSpeed()
            maxMistakes = customizationStore.getHardMaxMistakes()
            timeRemaining = 30.0
        } else {
            timeRemaining = 30.0
                    maxMistakes = 2
            roundTimeRemaining = 1.5
            confusionTimeRemaining = 1.8
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
        
        // Reset confusion timer state
        confusionTimeRemaining = 1.8
        endConfusionTimer()
        
        // Start new game session
        startGameSession()
    }
    
    // MARK: - Background/Foreground Handling
    
    private func setupBackgroundNotifications() {
        #if canImport(UIKit)
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
        #elseif os(macOS)
        NotificationCenter.default.addObserver(
            forName: NSApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.pauseTimer()
        }
        
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.resumeTimer()
        }
        #endif
    }
    
    private func removeBackgroundNotifications() {
        #if canImport(UIKit)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        #elseif os(macOS)
        NotificationCenter.default.removeObserver(self, name: NSApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: NSApplication.didBecomeActiveNotification, object: nil)
        #endif
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
        
        // Also pause confusion timer if active
        if isConfusionTimerActive {
            confusionTimer?.invalidate()
            confusionTimer = nil
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
        
        // Resume confusion timer if it was active and game is still active
        if isConfusionTimerActive && isGameActive && !isGameOver {
            startConfusionTimer()
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
    
    // Store the emotional message to prevent it from changing
    private let emotionalMessage: String
    
    init(score: Int, mistakes: Int, correctAnswers: Int, incorrectAnswers: Int, maxStreak: Int, bonusTriggers: Int, endReason: GameEndReason?, isNewBestScore: Bool, onBackToHome: @escaping () -> Void, onPlayAgain: @escaping () -> Void) {
        self.score = score
        self.mistakes = mistakes
        self.correctAnswers = correctAnswers
        self.incorrectAnswers = incorrectAnswers
        self.maxStreak = maxStreak
        self.bonusTriggers = bonusTriggers
        self.endReason = endReason
        self.isNewBestScore = isNewBestScore
        self.onBackToHome = onBackToHome
        self.onPlayAgain = onPlayAgain
        
        // Generate the emotional message once during initialization
        let messages = [
            "Nice reflexes!",
            "You nailed it!",
            "You are on fire!",
            "Well done!"
        ]
        self.emotionalMessage = messages.randomElement() ?? "Well done!"
    }
    
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
    
    // MARK: - Session Complete View (Figma Design)
    private var sessionCompleteView: some View {
        ZStack {
            // Confetti effects overlay
            sessionCompleteConfetti
            
            ScrollView {
                VStack(spacing: 30) {
                // Header Section
                VStack(spacing: 15) {
                    Text("⏰ Time's Up!")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                    
                    Text(emotionalMessage)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Main Score Circle
                ZStack {
                    // Score Circle Background
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.purple, .pink]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .overlay(
                            Circle()
                                .stroke(Color.blue.opacity(0.3), lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
                    
                    // Sparkle animation
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundColor(.yellow)
                        .offset(x: 70, y: -70)
                        .rotationEffect(.degrees(45))
                    
                            VStack(spacing: 8) {
                                // Trophy icon
                                Text("🏆")
                                    .font(.system(size: 40))
                                
                                // Score with pts
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(score)")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(.yellow)
                                    
                                    Text("pts")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                }
                            }
                }
                
                // Horizontal Breakdown Cards
                HStack(spacing: 8) {
                    // Correct Card
                    BreakdownCard(
                        icon: "✅",
                        label: "Correct",
                        count: correctAnswers,
                        points: correctAnswers * 10,
                        gradient: LinearGradient(
                            gradient: Gradient(colors: [
                                Color.green.opacity(0.6),
                                Color.green.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    
                    // Wrong Card
                    BreakdownCard(
                        icon: "❌",
                        label: "Wrong",
                        count: incorrectAnswers,
                        points: -(incorrectAnswers * 5),
                        gradient: LinearGradient(
                            gradient: Gradient(colors: [
                                Color.red.opacity(0.6),
                                Color.red.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    
                    // Streak Card
                    BreakdownCard(
                        icon: "🔥",
                        label: "Streak",
                        count: bonusTriggers,
                        points: bonusTriggers * 5,
                        gradient: LinearGradient(
                            gradient: Gradient(colors: [
                                Color.orange.opacity(0.6),
                                Color.orange.opacity(0.4)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                }
                .padding(.horizontal, 16)
                
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
                
                Spacer()
                
                    // Action Buttons (Figma Design)
                    sessionCompleteActionButtonsFigma
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
    }
    
    // MARK: - Game Over View (Figma Design)
    private var gameOverView: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header Section
                VStack(spacing: 15) {
                    // Skull emoji
                    Text("💀")
                        .font(.system(size: 50))
                    
                    // GAME OVER title with gradient
                    Text("GAME OVER")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.orange, .pink, .purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .multilineTextAlignment(.center)
                    
                    // Game over reason
                    Text(gameOverReason)
                        .font(.title3)
                        .fontWeight(.regular)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // Score Circle
                ZStack {
                    // Score Circle Background
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.17, green: 0.17, blue: 0.17), // #2B2B2B
                                    Color(red: 0.24, green: 0.24, blue: 0.24)  // #3C3C3C
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 200, height: 200)
                        .overlay(
                            Circle()
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 8)
                    
                    VStack(spacing: 8) {
                        // Broken heart icon
                        Text("💔")
                            .font(.system(size: 40))
                        
                        // Score with pts
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(score)")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text("pts")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
                
                // Action Buttons (same as Time's Up)
                gameOverActionButtons
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }
    }
    
    // MARK: - Game Over Action Buttons
    private var gameOverActionButtons: some View {
        VStack(spacing: 16) {
            // Play Again (Primary)
            Button(action: onPlayAgain) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("Play Again")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple, .pink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            
            // Back to Home (Secondary)
            Button(action: onBackToHome) {
                HStack(spacing: 12) {
                    Image(systemName: "house.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                    
                    Text("Back to Home")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
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
    
    
            // MARK: - Session Complete Confetti Effects
            private var sessionCompleteConfetti: some View {
                GeometryReader { geometry in
                    ZStack {
                        // Confetti effects - smaller size (60-70% of original)
                        ForEach(0..<8, id: \.self) { index in
                            Circle()
                                .fill(
                                    index % 2 == 0 ? 
                                    Color.pink.opacity(0.3) : 
                                    Color.blue.opacity(0.3)
                                )
                                .frame(width: CGFloat.random(in: 12...28)) // Reduced from 20-40 to 12-28
                                .position(
                                    x: CGFloat.random(in: 0...geometry.size.width),
                                    y: CGFloat.random(in: 0...geometry.size.height)
                                )
                                .blur(radius: 2)
                        }
                    }
                    .allowsHitTesting(false) // Allow touches to pass through
                }
            }
    
    // MARK: - Session Complete Action Buttons (Figma Design)
    private var sessionCompleteActionButtonsFigma: some View {
        VStack(spacing: 16) {
            // Play Again (Primary)
            Button(action: onPlayAgain) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(.white)
                    
                    Text("Play Again")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 55)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(27)
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            
            // Back to Home (Secondary)
            Button(action: onBackToHome) {
                HStack(spacing: 12) {
                    Image(systemName: "house.fill")
                        .font(.title3)
                        .foregroundColor(.primary)
                    
                    Text("Back to Home")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.bottom, 30)
    }
    
    // MARK: - Session Complete Action Buttons (Redesigned)
    private var sessionCompleteActionButtons: some View {
        VStack(spacing: 20) {
            // Play Again (Primary)
            Button(action: onPlayAgain) {
                Text("Play Again")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 55)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue, .purple]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(27)
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            }
            
            // Back to Home (Secondary)
            Button(action: onBackToHome) {
                Text("Back to Home")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 25)
                                    .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                            )
                    )
            }
        }
        .padding(.top, 20)
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

struct SimplifiedBreakdownRow: View {
    let icon: String
    let label: String
    let count: Int
    let points: Int
    let color: Color
    
    var body: some View {
        HStack {
            // Icon and label
            HStack(spacing: 8) {
                Text(icon)
                    .font(.title2)
                
                Text(label)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Count
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .frame(width: 30, alignment: .center)
            
            // Points
            Text("\(points >= 0 ? "+" : "")\(points) pts")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct BreakdownCard: View {
    let icon: String
    let label: String
    let count: Int
    let points: Int
    let gradient: LinearGradient
    
    var body: some View {
        VStack(spacing: 8) {
            // Icon and label
            HStack(spacing: 6) {
                Text(icon)
                    .font(.title3)
                    .foregroundColor(.primary)
                
                Text(label)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            // Count
            Text("\(count)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
            
            // Points with "pts"
            Text("\(points >= 0 ? "+" : "")\(points) pts")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 90)
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(gradient)
        )
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
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
