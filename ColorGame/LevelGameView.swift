import SwiftUI

struct LevelGameView: View {
    @ObservedObject var levelRun: LevelRun
    @Environment(\.dismiss) private var dismiss
    @StateObject private var customizationStore = CustomizationStore.shared
    
    // Game state
    @State private var announcedColor: Color = .red
    @State private var tiles: [Color] = []
    @State private var previousTiles: [Color] = []
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
    
    // Game over state
    @State private var isLevelComplete = false
    @State private var isLevelFailed = false
    
    // Color repeat tracking
    @State private var recentAnnouncedColors: [Color] = []
    
    // Services
    @State private var speechService = SpeechService()
    private let hapticsService = HapticsService.shared
    
    // Color palette
    private let colorPalette: [Color] = [.red, .blue, .green, .yellow]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Full screen background
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
                
                if isLevelComplete {
                    LevelCompleteView(
                        levelRun: levelRun,
                        onNextLevel: {
                            levelRun.completeLevel()
                            if levelRun.isCompleted {
                                // Show run complete screen
                                dismiss()
                            } else {
                                startNewLevel()
                            }
                        },
                        onBackToHome: {
                            dismiss()
                        }
                    )
                } else if isLevelFailed {
                    LevelFailedView(
                        levelRun: levelRun,
                        onRetry: {
                            startNewLevel()
                        },
                        onBackToHome: {
                            dismiss()
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
                            
                            // Dev-only skip button
                            if levelRun.shouldShowDevTools && !levelRun.isCompleted {
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
                        
                        // Level info and score
                        HStack {
                            Text("Level \(levelRun.currentLevel)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text("Score: \(levelRun.currentScore)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // Mistakes counter
                        HStack {
                            Text("Mistakes: \(levelRun.mistakes)/\(levelRun.mistakeTolerance.maxMistakes)")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(levelRun.mistakes >= levelRun.mistakeTolerance.maxMistakes ? .red : .primary)
                            
                            Spacer()
                            
                            if let levelConfig = levelRun.currentLevelConfig {
                                Text("Target: \(levelConfig.requiredScore)")
                                    .font(.title3)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
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
                        
                        // Round Progress Bar (if level has time limit)
                        if let levelConfig = levelRun.currentLevelConfig, levelConfig.hasTimeLimit {
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
                                            .fill(roundTimeRemaining > (levelConfig.timePerResponse ?? 1.0) * 0.3 ? Color.green : Color.red)
                                            .frame(width: geometry.size.width * (roundTimeRemaining / (levelConfig.timePerResponse ?? 1.0)), height: 8)
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
                                ColorTile(color: tiles.count > 0 ? tiles[0] : .gray, action: { handleTileTap(0) })
                                ColorTile(color: tiles.count > 1 ? tiles[1] : .gray, action: { handleTileTap(1) })
                            }
                            HStack(spacing: 20) {
                                ColorTile(color: tiles.count > 2 ? tiles[2] : .gray, action: { handleTileTap(2) })
                                ColorTile(color: tiles.count > 3 ? tiles[3] : .gray, action: { handleTileTap(3) })
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
            .navigationBarHidden(true)
            .onAppear {
                startLevel()
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
        guard isGameActive, isGameSessionActive, !isLevelComplete, !isLevelFailed else { return }
        
        // End round timer immediately
        endRoundTimer()
        
        let isCorrect: Bool
        guard index < tiles.count else { return }
        let tappedColor = tiles[index]
        isCorrect = tappedColor != announcedColor
        
        print("Tile tapped: \(colorName(for: tappedColor)), Announced: \(colorName(for: announcedColor)), Correct: \(isCorrect)")
        
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.isGameSessionActive && !self.isLevelComplete && !self.isLevelFailed {
                self.startNewRound()
            }
        }
    }
    
    private func checkLevelStatus() {
        guard let levelConfig = levelRun.currentLevelConfig else { return }
        
        // Only check for failure conditions during gameplay
        // Level completion is checked when timer runs out
        
        // Check if too many mistakes
        if levelRun.mistakes > levelRun.mistakeTolerance.maxMistakes {
            isLevelFailed = true
            return
        }
    }
    
    private func startLevel() {
        guard let levelConfig = levelRun.currentLevelConfig else { return }
        
        isGameSessionActive = true
        timeRemaining = Double(levelConfig.durationSeconds)
        
        // Start global timer
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 0.1
            } else {
                self.handleTimeUp()
            }
        }
        
        // Start first round
        startNewRound()
    }
    
    private func startNewLevel() {
        endGameSession() // Stop previous timer
        isLevelComplete = false
        isLevelFailed = false
        levelRun.resetLevelStats()
        startLevel()
    }
    
    private func startNewRound() {
        isGameActive = false
        
        // Store previous tiles for comparison
        previousTiles = tiles
        
        // Select random announced color with repeat prevention
        announcedColor = selectAnnouncedColor()
        
        // Update recent colors tracking
        updateRecentColors(announcedColor)
        
        // Speak the announced color
        speechService.speak(colorName(for: announcedColor))
        
        // Build valid grid
        tiles = buildValidGrid()
        
        // Enable game after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isGameActive = true
            
            // Start round timer if level has time limit
            if let levelConfig = levelRun.currentLevelConfig, levelConfig.hasTimeLimit {
                startRoundTimer(timeLimit: levelConfig.timePerResponse ?? 1.5)
            }
        }
    }
    
    private func buildValidGrid() -> [Color] {
        var attempts = 0
        let maxAttempts = 10
        
        while attempts < maxAttempts {
            var grid: [Color] = []
            
            // Add the announced color at least once
            grid.append(announcedColor)
            
            // Add at least one different color
            let nonAnnouncedColors = colorPalette.filter { $0 != announcedColor }
            if let differentColor = nonAnnouncedColors.randomElement() {
                grid.append(differentColor)
            }
            
            // Fill remaining slots randomly
            while grid.count < 4 {
                grid.append(colorPalette.randomElement() ?? .red)
            }
            
            // Shuffle the grid
            var shuffledGrid = grid.shuffled()
            
            // Check if different from previous round
            if shuffledGrid != previousTiles {
                return shuffledGrid
            }
            
            attempts += 1
        }
        
        // Fallback
        return [announcedColor, colorPalette.randomElement() ?? .blue, colorPalette.randomElement() ?? .green, colorPalette.randomElement() ?? .yellow].shuffled()
    }
    
    private func startRoundTimer(timeLimit: Double) {
        endRoundTimer()
        roundTimeRemaining = timeLimit
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
        guard isGameActive, isGameSessionActive, !isLevelComplete, !isLevelFailed else { return }
        
        levelRun.addTimeout()
        hapticsService.heavyImpact()
        showErrorFlash()
        
        endRoundTimer()
        checkLevelStatus()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if self.isGameSessionActive && !self.isLevelComplete && !self.isLevelFailed {
                self.startNewRound()
            }
        }
    }
    
    private func handleTimeUp() {
        endGameSession()
        
        // Check if level was completed successfully
        guard let levelConfig = levelRun.currentLevelConfig else { return }
        
        if levelRun.getCurrentLevelScore() >= levelConfig.requiredScore {
            isLevelComplete = true
        } else {
            isLevelFailed = true
        }
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
    }
    
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
        
        if isRoundTimerActive {
            roundTimer?.invalidate()
            roundTimer = nil
        }
    }
    
    private func resumeTimer() {
        guard isGameSessionActive, let backgroundTime = backgroundTime else { return }
        
        let elapsedTime = Date().timeIntervalSince(backgroundTime)
        timeRemaining -= elapsedTime
        
        if timeRemaining <= 0 {
            handleTimeUp()
            return
        }
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if self.timeRemaining > 0 {
                self.timeRemaining -= 0.1
            } else {
                self.handleTimeUp()
            }
        }
        
        if isRoundTimerActive {
            startRoundTimer(timeLimit: roundTimeRemaining)
        }
        
        self.backgroundTime = nil
    }
}

// MARK: - Level Complete View
struct LevelCompleteView: View {
    @ObservedObject var levelRun: LevelRun
    let onNextLevel: () -> Void
    let onBackToHome: () -> Void
    
    private var levelScore: Int {
        // Get the score for the current level only
        return levelRun.getCurrentLevelScore()
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("🎉")
                .font(.system(size: 60))
            
            Text("Level \(levelRun.currentLevel) Complete!")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Score to reach
            if let levelConfig = levelRun.currentLevelConfig {
                Text("Score to reach: \(levelConfig.requiredScore) points")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Your score (most visible)
            VStack(spacing: 8) {
                Text("Your score:")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(levelScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            
            // Total score
            Text("Total score: \(levelRun.globalScore)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            // Perfect bonus (only show for levels that have bonuses)
            if levelRun.isPerfectLevel, let levelConfig = levelRun.currentLevelConfig, levelConfig.perfectBonus != nil {
                VStack(spacing: 8) {
                    Text("🎉 Perfect Level!")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.green)
                    
                    Text("+\(levelRun.getPerfectBonus()) bonus points")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
            } else if let levelConfig = levelRun.currentLevelConfig, levelConfig.perfectBonus != nil {
                // Show bonus info even if not achieved
                VStack(spacing: 4) {
                    Text("Perfect bonus available: +\(levelConfig.perfectBonus!) points")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    Text("Complete with no mistakes and no timeouts")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            VStack(spacing: 16) {
                Button(action: onNextLevel) {
                    Text(levelRun.isCompleted ? "Finish Run" : "Next Level")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple)
                        .cornerRadius(25)
                }
                
                Button(action: onBackToHome) {
                    Text("Back to Home")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - Level Failed View
struct LevelFailedView: View {
    @ObservedObject var levelRun: LevelRun
    let onRetry: () -> Void
    let onBackToHome: () -> Void
    
    var body: some View {
        VStack(spacing: 30) {
            Text("💔")
                .font(.system(size: 60))
            
            Text("Level \(levelRun.currentLevel) Failed")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Score to reach
            if let levelConfig = levelRun.currentLevelConfig {
                Text("Score to reach: \(levelConfig.requiredScore) points")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            // Your score (most visible)
            VStack(spacing: 8) {
                Text("Your score:")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(levelRun.getCurrentLevelScore())")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 40)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.8))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
            
            // Total score
            Text("Total score: \(levelRun.globalScore)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.red)
                        .cornerRadius(25)
                }
                
                Button(action: onBackToHome) {
                    Text("Back to Home")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 45)
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(22)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

#Preview {
    LevelGameView(levelRun: LevelRun())
}
