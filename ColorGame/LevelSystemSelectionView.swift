import SwiftUI

struct LevelSystemSelectionView: View {
    @StateObject private var levelRun: LevelRun = {
        let run = LevelRun()
        run.mistakeTolerance = .easy
        return run
    }()
    @State private var currentStep: SelectionStep = .gameType
    @State private var isGameViewPresented = false
    @State private var selectedGameType: GameType?
    @State private var selectedMistakeTolerance: MistakeTolerance? = .easy // Pre-select Easy
    @State private var isRulesViewPresented = false
    @Binding var isPresented: Bool
    
    enum SelectionStep {
        case gameType
        case mistakeTolerance
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Top section with progress and back button
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 60)
                        
                        // Progress indicator
                        HStack(spacing: 8) {
                            ForEach(0..<2, id: \.self) { index in
                                Circle()
                                    .fill(index <= (currentStep == .gameType ? 0 : 1) ? Color.purple : Color.gray.opacity(0.3))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.bottom, 20)
                        
                        // Step title with back arrow
                        HStack {
                            Button(action: {
                                if currentStep == .mistakeTolerance {
                                    withAnimation { currentStep = .gameType }
                                } else {
                                    isPresented = false
                                }
                            }) {
                                Image(systemName: "arrow.left")
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
                            
                            Text(currentStep == .gameType ? "Choose Game Type" : "Choose Difficulty")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                            
                            // Invisible spacer to balance the back button
                            Color.clear
                                .frame(width: 32, height: 32)
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                    
                    // Content based on current step
                    if currentStep == .gameType {
                        gameTypeSelectionView
                    } else {
                        mistakeToleranceSelectionView
                    }
                    
                    Spacer()
                    
                    // Navigation buttons
                    VStack(spacing: 16) {
                        if currentStep == .mistakeTolerance {
                            // How to play button - above Start now button
                            Button(action: {
                                isRulesViewPresented = true
                            }) {
                                Text("How to play?")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(.primary)
                                    .underline()
                            }
                            .padding(.bottom, 20) // Space between "How to play?" and "Start now!"
                            
                            // Start Game button
                            Button(action: startLevelRun) {
                                HStack(spacing: 10) {
                                    Text("🚀")
                                        .font(.system(size: 20))
                                    
                                    Text("Start now!")
                                        .font(.system(size: 20, weight: .bold, design: .rounded))
                                        .foregroundColor(.white)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 55)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: canStartGame ? [.blue, .purple, .pink] : [.gray, .gray.opacity(0.7)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(27)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                            }
                            .disabled(!canStartGame)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
            }
            #if !os(macOS)
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            .fullScreenCover(isPresented: $isGameViewPresented) {
                LevelGameView(levelRun: levelRun)
            }
            .fullScreenCover(isPresented: $isRulesViewPresented) {
                RulesView(isPresented: $isRulesViewPresented)
            }
            #else
            .sheet(isPresented: $isGameViewPresented) {
                LevelGameView(levelRun: levelRun)
            }
            .sheet(isPresented: $isRulesViewPresented) {
                RulesView(isPresented: $isRulesViewPresented)
            }
            #endif
        }
        #if !os(macOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
    
    // MARK: - Game Type Selection View
    private var gameTypeSelectionView: some View {
        VStack(spacing: 30) {
            Text("How do you want to play?")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 20) {
                ForEach(GameType.allCases) { gameType in
                    Button(action: {
                        selectedGameType = gameType
                        levelRun.gameType = gameType
                        nextStep()
                    }) {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(gameType.displayName)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text(gameType.description)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedGameType == gameType ? Color.purple.opacity(0.1) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedGameType == gameType ? Color.purple : Color.clear, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Mistake Tolerance Selection View
    private var mistakeToleranceSelectionView: some View {
        VStack(spacing: 30) {
            Text("How many mistakes can you handle?")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 20) {
                ForEach(MistakeTolerance.allCases) { tolerance in
                    Button(action: {
                        selectedMistakeTolerance = tolerance
                        levelRun.mistakeTolerance = tolerance
                        // Ready to start game
                    }) {
                        VStack(spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(tolerance.displayName)
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.primary)
                                    
                                    Text(tolerance.description)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selectedMistakeTolerance == tolerance ? Color.purple.opacity(0.1) : Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(selectedMistakeTolerance == tolerance ? Color.purple : Color.clear, lineWidth: 2)
                                )
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Navigation Functions
    private func nextStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = .mistakeTolerance
            // Ensure Easy is selected when arriving at this step
            if selectedMistakeTolerance == nil {
                selectedMistakeTolerance = .easy
                levelRun.mistakeTolerance = .easy
            }
        }
    }
    
    private func startLevelRun() {
        // Validate that both selections are made
        guard let gameType = selectedGameType,
              let mistakeTolerance = selectedMistakeTolerance else {
            // Should not happen with pre-selection, but safety check
            return
        }
        
        levelRun.startRun(gameType: gameType, mistakeTolerance: mistakeTolerance)
        isGameViewPresented = true
    }
    
    // Computed property to check if game can start
    private var canStartGame: Bool {
        return selectedGameType != nil && selectedMistakeTolerance != nil
    }
}

#Preview {
    LevelSystemSelectionView(isPresented: .constant(true))
}
