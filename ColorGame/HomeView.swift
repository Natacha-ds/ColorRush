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
    @StateObject private var highScoreStore = HighScoreStore.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                // Best Score Display (top)
                VStack(spacing: 5) {
                    Text("Best Score: \(currentBestScore)")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.secondary)
                        .animation(.easeInOut(duration: 0.2), value: selectedDifficulty)
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Game Title
                VStack(spacing: 10) {
                    Text("ColorRush")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("Tap the squares that DON'T match the announced color!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                
                Spacer()
                
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
                                gradient: Gradient(colors: [.blue, .purple]),
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
                    .frame(width: 250)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $isGameViewPresented) {
                GameView(selectedDifficulty: selectedDifficulty)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Ensures portrait mode
    }
    
    private var currentBestScore: String {
        let score = highScoreStore.getBestScore(for: selectedDifficulty)
        return score > 0 ? "\(score)" : "—"
    }
}

#Preview {
    HomeView()
}
