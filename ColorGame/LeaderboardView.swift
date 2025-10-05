import SwiftUI

struct LeaderboardView: View {
    @StateObject private var leaderboardStore = LeaderboardStore.shared
    @State private var selectedDifficulty: Difficulty = .easy
    
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
                        .frame(height: 60)
                    
                    // Title
                    Text("Leaderboard")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    // Difficulty selector
                    Picker("Difficulty", selection: $selectedDifficulty) {
                        ForEach(Difficulty.allCases, id: \.self) { difficulty in
                            Text(difficulty.rawValue).tag(difficulty)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 280)
                    
                    Spacer()
                        .frame(height: 20)
                }
                
                // Scores list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        let scores = leaderboardStore.getScores(for: selectedDifficulty)
                        
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
                            .padding(.top, 60)
                        } else {
                            ForEach(Array(scores.enumerated()), id: \.element.id) { index, scoreEntry in
                                ScoreRowView(
                                    rank: index + 1,
                                    score: scoreEntry.score,
                                    date: scoreEntry.date,
                                    isTopThree: index < 3,
                                    difficulty: selectedDifficulty,
                                    durationSeconds: scoreEntry.durationSeconds,
                                    maxMistakes: scoreEntry.maxMistakes
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                
                Spacer()
                    .frame(height: 60)
            }
        }
        .navigationBarHidden(true)
    }
}

struct ScoreRowView: View {
    let rank: Int
    let score: Int
    let date: Date
    let isTopThree: Bool
    let difficulty: Difficulty
    let durationSeconds: Int?
    let maxMistakes: Int?
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .primary
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "number"
        }
    }
    
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                // Rank with icon
                HStack(spacing: 8) {
                    Image(systemName: rankIcon)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(rankColor)
                    
                    Text("#\(rank)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(rankColor)
                }
                .frame(width: 60, alignment: .leading)
                
                // Score
                Text("\(score)")
                    .font(.system(size: isTopThree ? 24 : 20, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Metadata for Easy mode
            if difficulty == .easy, let duration = durationSeconds, let mistakes = maxMistakes {
                HStack {
                    Spacer()
                        .frame(width: 60)
                    
                    Text("\(duration)s · \(mistakes) mistakes allowed")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        )
    }
}

#Preview {
    LeaderboardView()
}
