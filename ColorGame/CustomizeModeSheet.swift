import SwiftUI

struct CustomizeModeSheet: View {
    let difficulty: Difficulty
    @StateObject private var customizationStore = CustomizationStore.shared
    @State private var selectedDuration: Int
    @State private var selectedMaxMistakes: Int
    @State private var selectedRoundTimeout: Double
    @State private var selectedNormalMaxMistakes: Int
    @State private var selectedConfusionSpeed: Double
    @State private var selectedHardMaxMistakes: Int
    @Binding var isPresented: Bool
    @Binding var shouldStartGame: Bool
    
    init(difficulty: Difficulty, isPresented: Binding<Bool>, shouldStartGame: Binding<Bool>) {
        self.difficulty = difficulty
        self._isPresented = isPresented
        self._shouldStartGame = shouldStartGame
        // Initialize with default values, will be updated in onAppear
        self._selectedDuration = State(initialValue: 30)
        self._selectedMaxMistakes = State(initialValue: 3)
        self._selectedRoundTimeout = State(initialValue: 1.5)
        self._selectedNormalMaxMistakes = State(initialValue: 3)
        self._selectedConfusionSpeed = State(initialValue: 1.8)
        self._selectedHardMaxMistakes = State(initialValue: 3)
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissSheet()
                }
            
            // Bottom sheet
            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                // Content
                VStack(spacing: 32) {
                    // Title centered with close button anchored to top-right
                    ZStack {
                        // Centered title
                        Text("Customize your game")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(red: 0.3, green: 0.3, blue: 0.3)) // Softer dark gray
                        
                        // Close button anchored to top-right
                        HStack {
                            Spacer()
                            Button(action: {
                                dismissSheet()
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(Color.gray.opacity(0.1))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    
                    // Easy mode content
                    if difficulty == .easy {
                        VStack(spacing: 40) {
                            // Duration picker
                            VStack(spacing: 20) {
                                Text("⏱️ Duration")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.purple, .pink]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                // Custom segmented picker for Duration
                                HStack(spacing: 0) {
                                    ForEach(EasyDuration.allCases) { duration in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                selectedDuration = duration.rawValue
                                            }
                                        }) {
                                            Text(duration.displayName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(selectedDuration == duration.rawValue ? 
                                                                 Color.purple : 
                                                                 Color.gray)
                                                .frame(width: 66, height: 36)
                                                .background(
                                                    selectedDuration == duration.rawValue ?
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 18)
                                                                .stroke(
                                                                    LinearGradient(
                                                                        gradient: Gradient(colors: [.blue, .pink]),
                                                                        startPoint: .leading,
                                                                        endPoint: .trailing
                                                                    ),
                                                                    lineWidth: 2
                                                                )
                                                        ) :
                                                    nil
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                )
                                .frame(width: 200)
                            }
                            
                            // Max mistakes picker
                            VStack(spacing: 20) {
                                Text("❌ Mistakes allowed")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.purple, .pink]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                // Custom segmented picker for Max Mistakes
                                HStack(spacing: 0) {
                                    ForEach(MaxMistakes.allCases) { maxMistakes in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                selectedMaxMistakes = maxMistakes.rawValue
                                            }
                                        }) {
                                            Text(maxMistakes.displayName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(selectedMaxMistakes == maxMistakes.rawValue ? 
                                                                 Color.purple : 
                                                                 Color.gray)
                                                .frame(width: 60, height: 36)
                                                .background(
                                                    selectedMaxMistakes == maxMistakes.rawValue ?
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 18)
                                                                .stroke(
                                                                    LinearGradient(
                                                                        gradient: Gradient(colors: [.blue, .pink]),
                                                                        startPoint: .leading,
                                                                        endPoint: .trailing
                                                                    ),
                                                                    lineWidth: 2
                                                                )
                                                        ) :
                                                    nil
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                )
                                .frame(width: 240)
                            }
                        }
                    }
                    
                    // Hard mode content
                    if difficulty == .hard {
                        VStack(spacing: 40) {
                            // Confusion speed picker
                            VStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("⚡️ Confusion Speed")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(
                                            LinearGradient(
                                                gradient: Gradient(colors: [.purple, .pink]),
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    Text("How fast the board changes if you don't tap")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                // Custom segmented picker for Confusion Speed
                                HStack(spacing: 0) {
                                    ForEach(HardConfusionSpeed.allCases) { speed in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                selectedConfusionSpeed = speed.rawValue
                                            }
                                        }) {
                                            Text(speed.displayName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(selectedConfusionSpeed == speed.rawValue ? 
                                                                 Color.purple : 
                                                                 Color.gray)
                                                .frame(width: 80, height: 36)
                                                .background(
                                                    selectedConfusionSpeed == speed.rawValue ?
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 18)
                                                                .stroke(
                                                                    LinearGradient(
                                                                        gradient: Gradient(colors: [.blue, .pink]),
                                                                        startPoint: .leading,
                                                                        endPoint: .trailing
                                                                    ),
                                                                    lineWidth: 2
                                                                )
                                                        ) :
                                                    nil
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                )
                                .frame(width: 240)
                            }
                            
                            // Max mistakes picker
                            VStack(spacing: 20) {
                                Text("❌ Mistakes allowed")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.purple, .pink]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                // Custom segmented picker for Max Mistakes
                                HStack(spacing: 0) {
                                    ForEach(MaxMistakes.allCases) { maxMistakes in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                selectedHardMaxMistakes = maxMistakes.rawValue
                                            }
                                        }) {
                                            Text(maxMistakes.displayName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(selectedHardMaxMistakes == maxMistakes.rawValue ? 
                                                                 Color.purple : 
                                                                 Color.gray)
                                                .frame(width: 60, height: 36)
                                                .background(
                                                    selectedHardMaxMistakes == maxMistakes.rawValue ?
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 18)
                                                                .stroke(
                                                                    LinearGradient(
                                                                        gradient: Gradient(colors: [.blue, .pink]),
                                                                        startPoint: .leading,
                                                                        endPoint: .trailing
                                                                    ),
                                                                    lineWidth: 2
                                                                )
                                                        ) :
                                                    nil
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                )
                                .frame(width: 240)
                            }
                        }
                    }
                    
                    // Normal mode content
                    if difficulty == .normal {
                        VStack(spacing: 40) {
                            // Round timeout picker
                            VStack(spacing: 20) {
                                Text("⏱️ Per-Round Timeout")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.purple, .pink]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                // Custom segmented picker for Round Timeout
                                HStack(spacing: 0) {
                                    ForEach(NormalRoundTimeout.allCases) { timeout in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                selectedRoundTimeout = timeout.rawValue
                                            }
                                        }) {
                                            Text(timeout.displayName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(selectedRoundTimeout == timeout.rawValue ? 
                                                                 Color.purple : 
                                                                 Color.gray)
                                                .frame(width: 80, height: 36)
                                                .background(
                                                    selectedRoundTimeout == timeout.rawValue ?
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 18)
                                                                .stroke(
                                                                    LinearGradient(
                                                                        gradient: Gradient(colors: [.blue, .pink]),
                                                                        startPoint: .leading,
                                                                        endPoint: .trailing
                                                                    ),
                                                                    lineWidth: 2
                                                                )
                                                        ) :
                                                    nil
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                )
                                .frame(width: 240)
                            }
                            
                            // Max mistakes picker
                            VStack(spacing: 20) {
                                Text("❌ Mistakes allowed")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.purple, .pink]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                
                                // Custom segmented picker for Max Mistakes
                                HStack(spacing: 0) {
                                    ForEach(MaxMistakes.allCases) { maxMistakes in
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                selectedNormalMaxMistakes = maxMistakes.rawValue
                                            }
                                        }) {
                                            Text(maxMistakes.displayName)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(selectedNormalMaxMistakes == maxMistakes.rawValue ? 
                                                                 Color.purple : 
                                                                 Color.gray)
                                                .frame(width: 60, height: 36)
                                                .background(
                                                    selectedNormalMaxMistakes == maxMistakes.rawValue ?
                                                    RoundedRectangle(cornerRadius: 18)
                                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 18)
                                                                .stroke(
                                                                    LinearGradient(
                                                                        gradient: Gradient(colors: [.blue, .pink]),
                                                                        startPoint: .leading,
                                                                        endPoint: .trailing
                                                                    ),
                                                                    lineWidth: 2
                                                                )
                                                        ) :
                                                    nil
                                                )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 18)
                                        .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                                        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                                )
                                .frame(width: 240)
                            }
                        }
                    }
                    
                    // Action buttons (only for Easy mode - others use X close)
                    if difficulty == .easy {
                        Button(action: {
                            startGame()
                        }) {
                            HStack(spacing: 10) {
                                Text("⚡️")
                                    .font(.system(size: 20))
                                
                                Text("PLAY")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 160, height: 50)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple, .pink]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                    } else {
                        // For Normal and Hard modes, use the same gradient button design
                        Button(action: {
                            startGame()
                        }) {
                            HStack(spacing: 10) {
                                Text("⚡️")
                                    .font(.system(size: 20))
                                
                                Text("PLAY")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .frame(width: 160, height: 50)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [.blue, .purple, .pink]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34) // Extra padding for safe area
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.98, green: 0.98, blue: 0.99)) // #FAFAFB - slightly off-white
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
            )
            .frame(maxWidth: 320)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .onAppear {
            // Load current settings when sheet appears
            if difficulty == .easy {
                selectedDuration = customizationStore.getEasyDuration()
                selectedMaxMistakes = customizationStore.getEasyMaxMistakes()
            } else if difficulty == .normal {
                selectedRoundTimeout = customizationStore.getNormalRoundTimeout()
                selectedNormalMaxMistakes = customizationStore.getNormalMaxMistakes()
            } else if difficulty == .hard {
                selectedConfusionSpeed = customizationStore.getHardConfusionSpeed()
                selectedHardMaxMistakes = customizationStore.getHardMaxMistakes()
            }
        }
    }
    
    private func dismissSheet() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
    }
    
    private func startGame() {
        // Save selected settings based on difficulty
        if difficulty == .easy {
            customizationStore.updateEasySettings(duration: selectedDuration, maxMistakes: selectedMaxMistakes)
        } else if difficulty == .normal {
            customizationStore.updateNormalSettings(roundTimeout: selectedRoundTimeout, maxMistakes: selectedNormalMaxMistakes)
        } else if difficulty == .hard {
            customizationStore.updateHardSettings(confusionSpeed: selectedConfusionSpeed, maxMistakes: selectedHardMaxMistakes)
        }
        
        // Set flag to start game
        shouldStartGame = true
        
        // Dismiss sheet
        dismissSheet()
    }
}

#Preview {
    CustomizeModeSheet(
        difficulty: .easy,
        isPresented: .constant(true),
        shouldStartGame: .constant(false)
    )
}

// Triangle shape for tooltip caret
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
