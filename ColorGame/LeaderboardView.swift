import SwiftUI

struct LeaderboardView: View {
    @StateObject private var leaderboardStore = LeaderboardStore.shared
    @State private var selectedMistakeTolerance: MistakeTolerance = .easy
    
    var body: some View {
        ZStack {
            // Background gradient (same as HomeView)
            LinearGradient(
                gradient: Gradient(colors: [Color.purple.opacity(0.1), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with title and difficulty selector
                VStack(spacing: 20) {
                    Spacer()
                        .frame(height: 40)
                    
                    // Title with trophy icon and gradient
                    Text("🏆 Leaderboard")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [.pink, .purple, .blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    
                    // Mistake Tolerance selector with capsule style
                    HStack(spacing: 0) {
                        ForEach(MistakeTolerance.allCases, id: \.self) { tolerance in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedMistakeTolerance = tolerance
                                }
                            }) {
                                Text(tolerance.displayName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(selectedMistakeTolerance == tolerance ? 
                                                     Color.purple : 
                                                     Color.gray)
                                    .frame(width: 93, height: 36)
                                    .background(
                                        // Individual button background - only for selected state
                                        selectedMistakeTolerance == tolerance ?
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
                    
                    Spacer()
                        .frame(height: 20)
                }
                
                // Scores list (top 5 only, no scrolling)
                VStack(spacing: 12) {
                    let scores = leaderboardStore.getScores(for: selectedMistakeTolerance)
                    let topFiveScores = Array(scores.prefix(5)) // Show only top 5
                    
                    if scores.isEmpty {
                        // Empty state
                        VStack(spacing: 16) {
                            Image(systemName: "trophy")
                                .font(.system(size: 48))
                                .foregroundColor(.gray.opacity(0.6))
                            
                            Text("No scores yet")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            Text("Play some games to see your scores here!")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ForEach(Array(topFiveScores.enumerated()), id: \.element.id) { index, scoreEntry in
                            ScoreRowView(
                                rank: index + 1,
                                score: scoreEntry.score,
                                isTopThree: index < 3
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxHeight: .infinity)
                
                Spacer()
                    .frame(height: 60)
            }
        }
        #if !os(macOS)
        .navigationBarHidden(true)
        #endif
    }
}

struct ScoreRowView: View {
    let rank: Int
    let score: Int
    let isTopThree: Bool
    
    private var rankIcon: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        default: return "\(rank)"
        }
    }
    
    private var backgroundColor: Color {
        switch rank {
        case 1: return Color(red: 1.0, green: 0.96, blue: 0.85) // #FFF6DA - light gold
        case 2: return Color(red: 0.96, green: 0.96, blue: 0.97) // #F5F5F7 - light silver
        case 3: return Color(red: 0.98, green: 0.90, blue: 0.82) // #F9E5D0 - light bronze
        default: return Color(red: 0.98, green: 0.98, blue: 0.99) // #FAFAFA - off-white
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank with medal/number (left side)
            HStack(spacing: 8) {
                if isTopThree {
                    Text(rankIcon)
                        .font(.system(size: 24))
                } else {
                    Text("\(rank)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                }
            }
            .frame(width: 50, alignment: .leading)
            
            // Score (center, expanding)
            Text("\(score)")
                .font(.system(size: isTopThree ? 28 : 22, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Crown icon for 1st place (far right)
            if rank == 1 {
                Text("👑")
                    .font(.system(size: 24))
                    .padding(.leading, 8)
            } else {
                // Spacer to maintain alignment
                Spacer()
                    .frame(width: 32)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, isTopThree ? 18 : 14)
        .background(
            RoundedRectangle(cornerRadius: isTopThree ? 16 : 12)
                .fill(backgroundColor)
                .shadow(color: .black.opacity(0.15), radius: isTopThree ? 8 : 4, x: 0, y: isTopThree ? 4 : 2)
        )
    }
}

#Preview {
    LeaderboardView()
}
