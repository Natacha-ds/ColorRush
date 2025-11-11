//
//  RulesView.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import SwiftUI

struct RulesView: View {
    @Binding var isPresented: Bool
    
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
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Title - centered
                        HStack {
                            Spacer()
                            Text("How to Play")
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.purple, .pink]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            Spacer()
                        }
                        .padding(.top, 20)
                        
                        // Goal section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🎯 Goal")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Tap any color except the one that's said out loud.")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        // Gameplay section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("⚡ Gameplay")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("• Each correct tap gives points (value depends on level).")
                                Text("• Wrong color → −10 pts and −1 life.")
                                Text("• No tap in time → −5 pts.")
                                Text("• Fail to reach target score → −1 life, no point loss.")
                            }
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                        }
                        
                        // Streak Bonus section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🔥 Streak Bonus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Earn extra points for consecutive correct taps:")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text("• 10 in a row → +20 pts")
                                Text("• 20 in a row → +50 pts total (includes the first 20)")
                                Text("• 30 in a row → +80 pts total (includes all previous bonuses)")
                            }
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(.secondary)
                            .padding(.leading, 8)
                        }
                        
                        // Lives section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("💔 Lives")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("You start with limited lives. Lose them all = Game Over.")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        // Levels section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("🏆 Levels")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text("Each level has a target score to beat.")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
                }
            }
            #if !os(macOS)
            .navigationBarHidden(true)
            .navigationBarBackButtonHidden(true)
            #endif
            .overlay(
                // Back button in top left
                VStack {
                    HStack {
                        Button(action: {
                            isPresented = false
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
                        .padding(.leading, 20)
                        .padding(.top, 10)
                        
                        Spacer()
                    }
                    Spacer()
                }
            )
        }
        #if !os(macOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }
}

#Preview {
    RulesView(isPresented: .constant(true))
}

