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
    @StateObject private var highScoreStore = HighScoreStore.shared
    
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
                    // Top section with Best Score
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 60)
                        
                        // Best Score Display with trophy icon
                        HStack(spacing: 8) {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 16, weight: .medium))
                            
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
                            .frame(height: 40)
                    }
                    
                    // Middle section with title and instructions
                    VStack(spacing: 20) {
                        // Color squares
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.8))
                                .frame(width: 24, height: 24)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.8))
                                .frame(width: 24, height: 24)
                            
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.yellow.opacity(0.8))
                                .frame(width: 24, height: 24)
                        }
                        
                        // Game Title
                        Text("ColorRush")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        // Instructions with highlighted "DON'T"
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Text("Tap the squares that ")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Text("DON'T")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            
                            Text("match the announced color!")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                        }
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    // Bottom section with Play button and difficulty
                    VStack(spacing: 30) {
                        // Play Button
                        Button(action: {
                            isGameViewPresented = true
                        }) {
                            Text("PLAY")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 200, height: 60)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.blue, .pink]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(30)
                                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        }
                        .scaleEffect(isGameViewPresented ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: isGameViewPresented)
                        
                        // Difficulty Selector
                        VStack(spacing: 15) {
                            Text("Difficulty")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Picker("Difficulty", selection: $selectedDifficulty) {
                                ForEach(Difficulty.allCases, id: \.self) { difficulty in
                                    Text(difficulty.rawValue).tag(difficulty)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
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
                .navigationBarHidden(true)
                .fullScreenCover(isPresented: $isGameViewPresented) {
                    GameView(selectedDifficulty: selectedDifficulty)
                }
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
            .navigationViewStyle(StackNavigationViewStyle()) // Ensures portrait mode
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
