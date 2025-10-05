import SwiftUI

struct CustomizeModeSheet: View {
    let difficulty: Difficulty
    @StateObject private var customizationStore = CustomizationStore.shared
    @State private var selectedDuration: Int
    @State private var selectedMaxMistakes: Int
    @Binding var isPresented: Bool
    @Binding var shouldStartGame: Bool
    
    init(difficulty: Difficulty, isPresented: Binding<Bool>, shouldStartGame: Binding<Bool>) {
        self.difficulty = difficulty
        self._isPresented = isPresented
        self._shouldStartGame = shouldStartGame
        self._selectedDuration = State(initialValue: CustomizationStore.shared.getEasyDuration())
        self._selectedMaxMistakes = State(initialValue: CustomizationStore.shared.getEasyMaxMistakes())
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
                VStack(spacing: 24) {
                    // Title
                    Text("Customize \(difficulty.rawValue)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    // Easy mode content
                    if difficulty == .easy {
                        VStack(spacing: 24) {
                            // Duration picker
                            VStack(spacing: 12) {
                                Text("Duration")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Picker("Duration", selection: $selectedDuration) {
                                    ForEach(EasyDuration.allCases) { duration in
                                        Text(duration.displayName).tag(duration.rawValue)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 200)
                            }
                            
                            // Max mistakes picker
                            VStack(spacing: 12) {
                                Text("Max Mistakes")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Picker("Max Mistakes", selection: $selectedMaxMistakes) {
                                    ForEach(MaxMistakes.allCases) { maxMistakes in
                                        Text(maxMistakes.displayName).tag(maxMistakes.rawValue)
                                    }
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .frame(width: 240)
                                
                                // Description text
                                Text(MaxMistakes(rawValue: selectedMaxMistakes)?.description ?? "")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .animation(.easeInOut(duration: 0.2), value: selectedMaxMistakes)
                            }
                        }
                    }
                    
                    // Normal/Hard mode placeholders
                    if difficulty == .normal || difficulty == .hard {
                        VStack(spacing: 16) {
                            Image(systemName: "gear")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            Text("Coming Soon")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("Customization options for \(difficulty.rawValue) mode will be available in a future update.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 20)
                    }
                    
                    // Action buttons
                    HStack(spacing: 16) {
                        // Close button
                        Button(action: {
                            dismissSheet()
                        }) {
                            Text("Close")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(width: 100, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(Color.gray.opacity(0.2))
                                )
                        }
                        
                        // Start button (only for Easy mode)
                        if difficulty == .easy {
                            Button(action: {
                                startGame()
                            }) {
                                Text("Start")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 100, height: 44)
                                    .background(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.blue, .pink]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .cornerRadius(22)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34) // Extra padding for safe area
            }
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: -5)
            )
            .frame(maxWidth: .infinity)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .onAppear {
            // Load current settings when sheet appears
            selectedDuration = customizationStore.getEasyDuration()
            selectedMaxMistakes = customizationStore.getEasyMaxMistakes()
        }
    }
    
    private func dismissSheet() {
        withAnimation(.easeInOut(duration: 0.25)) {
            isPresented = false
        }
    }
    
    private func startGame() {
        // Save both selected settings
        customizationStore.updateEasySettings(duration: selectedDuration, maxMistakes: selectedMaxMistakes)
        
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
