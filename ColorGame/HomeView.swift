//
//  HomeView.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import SwiftUI

enum Difficulty: String, CaseIterable {
    case easy = "Easy"
    case normal = "Normal"
    case hard = "Hard"
}

struct HomeView: View {
    @State private var selectedDifficulty: Difficulty = .normal
    @State private var isGameViewPresented = false
    @State private var isCustomizeSheetPresented = false
    @State private var shouldStartGame = false
    @State private var isLevelSystemSelectionPresented = false
    @StateObject private var highScoreStore = HighScoreStore.shared
    @StateObject private var customizationStore = CustomizationStore.shared
    
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
                    // Top section with Old/New Toggle and Best Score
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 60)
                        
                        // Old/New System Toggle
                        HStack(spacing: 8) {
                            Text("Old")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(customizationStore.isLevelSystemEnabled ? .gray : .primary)
                            
                            Toggle("", isOn: $customizationStore.isLevelSystemEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .purple))
                                .onChange(of: customizationStore.isLevelSystemEnabled) { _, newValue in
                                    customizationStore.setLevelSystemEnabled(newValue)
                                }
                            
                            Text("New")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(customizationStore.isLevelSystemEnabled ? .primary : .gray)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                        )
                        
                        Spacer()
                            .frame(height: 20)
                        
                        // Best Score Display with trophy icon
                        HStack(spacing: 8) {
                            Text("🏆")
                                .font(.system(size: 16))
                            
                            Text("Best Score:")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text(currentBestScore)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                        )
                        .animation(.easeInOut(duration: 0.2), value: selectedDifficulty)
                        
                        Spacer()
                            .frame(height: 50) // Increased spacing
                    }
                    
                    // Title & Branding Area
                    VStack(spacing: 20) {
                        // 4 Color swatches above the title
                        HStack(spacing: 16) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.8))
                                .frame(width: 28, height: 28)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.8))
                                .frame(width: 28, height: 28)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.yellow.opacity(0.8))
                                .frame(width: 28, height: 28)
                            
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green.opacity(0.8))
                                .frame(width: 28, height: 28)
                        }
                        
                        // Game Title with gradient
                        Text("ColorRush")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [.purple, .pink, .blue]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Spacer()
                            .frame(height: 25) // More space between title and instructions
                        
                        // Instructions with highlighted "DON'T"
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Text("Tap the squares that ")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text("DON'T")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.blue) // Changed to blue like the color square
                            }
                            
                            Text("match the announced color!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                        .frame(minHeight: 40) // More balanced spacing
                    
                    // Play Button (Centered CTA)
                    Button(action: {
                        if customizationStore.isLevelSystemEnabled {
                            isLevelSystemSelectionPresented = true
                        } else {
                            isGameViewPresented = true
                        }
                    }) {
                        HStack(spacing: 10) {
                            Text("⚡️")
                                .font(.system(size: 20))
                            
                            Text(customizationStore.isLevelSystemEnabled ? "Play now" : "PLAY")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }
                        .frame(width: 200, height: 60)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .purple, .pink]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(30)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                    }
                    .scaleEffect(isGameViewPresented ? 0.95 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isGameViewPresented)
                    
                    Spacer()
                        .frame(minHeight: 40) // More balanced spacing
                    
                    // Mode Selector (only show in old system)
                    if !customizationStore.isLevelSystemEnabled {
                        VStack(spacing: 15) {
                            Text("Mode")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            // Custom segmented picker with seamless capsule design
                            HStack(spacing: 0) {
                                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            selectedDifficulty = difficulty
                                        }
                                    }) {
                                        Text(difficulty.rawValue)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(selectedDifficulty == difficulty ? 
                                                             Color.purple : 
                                                             Color.gray)
                                            .frame(width: 93, height: 36)
                                            .background(
                                                // Individual button background - only for selected state
                                                selectedDifficulty == difficulty ?
                                                RoundedRectangle(cornerRadius: 18)
                                                    .fill(Color.white)
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
                                // Single white container for all buttons
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color.white)
                                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                            )
                            .frame(width: 280)
                            .onChange(of: selectedDifficulty) { _, _ in
                                // Open customization sheet when difficulty changes
                                isCustomizeSheetPresented = true
                            }
                        }
                    }
                    
                    Spacer()
                        .frame(height: 60)
                }
            }
                #if !os(macOS)
                .navigationBarHidden(true)
                .fullScreenCover(isPresented: $isGameViewPresented) {
                    GameView(selectedDifficulty: selectedDifficulty)
                }
                .fullScreenCover(isPresented: $isLevelSystemSelectionPresented) {
                    LevelSystemSelectionView(isPresented: $isLevelSystemSelectionPresented)
                }
                #else
                .sheet(isPresented: $isGameViewPresented) {
                    GameView(selectedDifficulty: selectedDifficulty)
                }
                .sheet(isPresented: $isLevelSystemSelectionPresented) {
                    LevelSystemSelectionView(isPresented: $isLevelSystemSelectionPresented)
                }
                #endif
                .overlay(
                    // Customization sheet overlay
                    Group {
                        if isCustomizeSheetPresented {
                            CustomizeModeSheet(
                                difficulty: selectedDifficulty,
                                isPresented: $isCustomizeSheetPresented,
                                shouldStartGame: $shouldStartGame
                            )
                        }
                    }
                )
            }
            #if !os(macOS)
            .navigationViewStyle(StackNavigationViewStyle()) // Ensures portrait mode
            #endif
            .onChange(of: shouldStartGame) { _, shouldStart in
                if shouldStart {
                    isGameViewPresented = true
                    shouldStartGame = false // Reset the flag
                }
            }
    }
    
    private var currentBestScore: String {
        let score = highScoreStore.getBestScore(for: selectedDifficulty)
        return score > 0 ? "\(score)" : "—"
    }
}

#Preview {
    HomeView()
}
