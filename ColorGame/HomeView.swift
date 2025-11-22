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
    @State private var isLevelSystemSelectionPresented = false
    @State private var isRulesViewPresented = false
    @StateObject private var leaderboardStore = LeaderboardStore.shared
    
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
                .preferredColorScheme(.light)
                
                VStack(spacing: 0) {
                    // Top section with Best Score
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 60)
                        
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
                        isLevelSystemSelectionPresented = true
                    }) {
                        HStack(spacing: 10) {
                            Text("⚡️")
                                .font(.system(size: 20))
                            
                            Text("Play now")
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
                    
                    Spacer()
                        .frame(minHeight: 40) // More balanced spacing
                    
                    Spacer()
                        .frame(height: 60)
                }
            }
                #if !os(macOS)
                .navigationBarHidden(true)
                .fullScreenCover(isPresented: $isLevelSystemSelectionPresented) {
                    LevelSystemSelectionView(isPresented: $isLevelSystemSelectionPresented)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToLeaderboard"))) { _ in
                    // Dismiss the selection view if it's presented
                    isLevelSystemSelectionPresented = false
                    // Switch to leaderboard tab (handled by MainTabView)
                }
                .fullScreenCover(isPresented: $isRulesViewPresented) {
                    RulesView(isPresented: $isRulesViewPresented)
                }
                #else
                .sheet(isPresented: $isLevelSystemSelectionPresented) {
                    LevelSystemSelectionView(isPresented: $isLevelSystemSelectionPresented)
                }
                .sheet(isPresented: $isRulesViewPresented) {
                    RulesView(isPresented: $isRulesViewPresented)
                }
                #endif
            }
            #if !os(macOS)
            .navigationViewStyle(StackNavigationViewStyle()) // Ensures portrait mode
            #endif
    }
    
    private var currentBestScore: String {
        let score = leaderboardStore.getOverallBestScore()
        return score > 0 ? "\(score)" : "—"
    }
}

#Preview {
    HomeView()
}
