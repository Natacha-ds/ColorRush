//
//  RulesView.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import SwiftUI

struct RulesView: View {
  @Binding var isPresented: Bool
  var gameType: GameType? // Optional game type to adapt content

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

              if gameType == .colorAndText {
                VStack(alignment: .leading, spacing: 6) {
                  Text("Tap any tile that does NOT match:")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                  Text("• the spoken color")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                  Text("• the written word on the tile.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.secondary)
                    .padding(.leading, 8)
                }
              } else {
                Text("Tap any color except the one spoken out loud.")
                  .font(.system(size: 16, weight: .regular))
                  .foregroundColor(.secondary)
              }
            }

            // Gameplay section
            VStack(alignment: .leading, spacing: 8) {
              Text("⚡ Gameplay")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

              VStack(alignment: .leading, spacing: 6) {
                Text(
                  "• Correct tap → scores points (value depends on the level)."
                )
                Text("• Wrong tap → −10 pts")
                Text("• No tap in time → −5 pts")
              }
              .font(.system(size: 16, weight: .regular))
              .foregroundColor(.secondary)
            }

            // Streak Bonus section
            VStack(alignment: .leading, spacing: 8) {
              if gameType == .colorAndText {
                Text("🔥 Streak Bonus (Color + Text only)")
                  .font(.system(size: 22, weight: .bold))
                  .foregroundColor(.primary)

                VStack(alignment: .leading, spacing: 6) {
                  Text("• Every 5 consecutive correct taps → +10 pts bonus")
                  Text("• Streak resets on any mistake or missed tap.")
                }
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .padding(.leading, 8)
              } else {
                Text("🔥 Streak Bonus")
                  .font(.system(size: 22, weight: .bold))
                  .foregroundColor(.primary)

                Text("Extra points for consecutive correct taps:")
                  .font(.system(size: 16, weight: .regular))
                  .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                  Text("• 10 in a row → +20 pts")
                  Text("• 20 in a row → +50 pts total")
                  Text("• 30 in a row → +80 pts total")
                }
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .padding(.leading, 8)
              }
            }

            // Lives section
            VStack(alignment: .leading, spacing: 8) {
              Text("💔 Lives")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

              VStack(alignment: .leading, spacing: 6) {
                Text("• You start with a limited number of lives.")
                Text("• Fail a level → −1 life.")
                Text("• Lose all lives → Game Over.")
              }
              .font(.system(size: 16, weight: .regular))
              .foregroundColor(.secondary)
            }

            // Levels section
            VStack(alignment: .leading, spacing: 8) {
              Text("🏆 Levels")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

              if gameType == .colorAndText {
                Text(
                  "Each level has a target score. The mode is trickier, so stay laser-focused and keep your streak alive!"
                )
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
              } else {
                Text(
                  "Each level has a target score. Be fast, stay sharp, and chain streaks to climb higher!"
                )
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
              }
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
