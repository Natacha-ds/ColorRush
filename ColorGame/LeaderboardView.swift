import SwiftUI

// MARK: - View-layer brand labels

private extension GameType {
  var brandLabel: LocalizedStringKey {
    switch self {
    case .colorOnly: "COLOR"
    case .colorAndText: "COLOR+WORD"
    }
  }
}

private extension MistakeTolerance {
  var brandLabel: LocalizedStringKey {
    switch self {
    case .easy: "ROOKIE"
    case .normal: "PRO"
    case .hard: "INSANE"
    }
  }
}

// MARK: - Display row union

private enum DisplayRow: Identifiable {
  case gc(GameCenterEntry)
  case local(rank: Int, score: Int)

  var id: String {
    switch self {
    case let .gc(entry): "gc-\(entry.id)"
    case let .local(rank, _): "local-\(rank)"
    }
  }

  var rank: Int {
    switch self {
    case let .gc(entry): entry.rank
    case let .local(rank, _): rank
    }
  }

  var displayName: String? {
    switch self {
    case let .gc(entry): entry.displayName
    case .local: nil
    }
  }

  var formattedScore: String {
    switch self {
    case let .gc(entry): entry.formattedScore
    case let .local(_, score): "\(score)"
    }
  }

  var isLocalPlayer: Bool {
    switch self {
    case let .gc(entry): entry.isLocalPlayer
    case .local: false
    }
  }
}

// MARK: - LeaderboardView

struct LeaderboardView: View {
  @StateObject private var leaderboardStore = LeaderboardStore.shared
  @StateObject private var gameCenter = GameCenterService.shared
  @State private var selectedGameType: GameType = .colorOnly
  @State private var selectedMistakeTolerance: MistakeTolerance = .easy

  private var currentKey: LeaderboardKey {
    LeaderboardKey(
      gameType: selectedGameType,
      mistakeTolerance: selectedMistakeTolerance
    )
  }

  /// Hybrid data resolution: GC top entries when available, local top-5 as fallback.
  private var displayedRows: [DisplayRow] {
    if gameCenter.isAuthenticated,
       let gcEntries = gameCenter.topEntries[currentKey],
       !gcEntries.isEmpty {
      return gcEntries.map { .gc($0) }
    }
    let localScores = leaderboardStore.getScores(
      gameType: selectedGameType,
      mistakeTolerance: selectedMistakeTolerance
    )
    return localScores.enumerated().map { index, entry in
      .local(rank: index + 1, score: entry.score)
    }
  }

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
      Text("RANKS")
        .font(.crTitle)
        .textCase(.uppercase)
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.top, Theme.Spacing.lg)
        .padding(.horizontal, Theme.Spacing.xl)

      modeSelector
        .padding(.horizontal, Theme.Spacing.xl)

      difficultySelector
        .padding(.horizontal, Theme.Spacing.xl)

      if let rankPill {
        rankPill
          .padding(.horizontal, Theme.Spacing.xl)
      }

      scoreList
        .padding(.horizontal, Theme.Spacing.xl)

      Spacer(minLength: 0)

      globalRankingCTA
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.bottom, Theme.Spacing.lg)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.Colors.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
    .onAppear {
      LogService.shared.log("leaderboard_opened")
    }
    .task {
      await refreshAll()
    }
    .onChange(of: selectedGameType) { _, _ in
      Task { await refreshAll() }
    }
    .onChange(of: selectedMistakeTolerance) { _, _ in
      Task { await refreshAll() }
    }
    .onChange(of: gameCenter.isAuthenticated) { _, isAuth in
      if isAuth {
        Task { await refreshAll() }
      }
    }
  }

  // MARK: Mode selector

  private var modeSelector: some View {
    HStack(spacing: 0) {
      ForEach(GameType.allCases) { gameType in
        modeTab(for: gameType)
      }
    }
    .padding(Theme.Spacing.xs)
    .background(
      Capsule(style: .continuous)
        .fill(Theme.Colors.surface)
    )
    .frame(maxWidth: .infinity)
  }

  private func modeTab(for gameType: GameType) -> some View {
    let isActive = gameType == selectedGameType
    return Button {
      SoundService.shared.play(.secondary)
      LogService.shared.log("leaderboard_mode_changed", [
        "gameType": gameType.rawValue,
      ])
      withAnimation(.easeOut(duration: 0.15)) {
        selectedGameType = gameType
      }
    } label: {
      Text(gameType.brandLabel)
        .font(.crLabel)
        .textCase(.uppercase)
        .foregroundStyle(
          isActive ? Theme.Colors.textPrimary : Theme.Colors.textSecondary
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm)
        .background(
          Capsule(style: .continuous)
            .fill(isActive ? Theme.Colors.surfaceElevated : Color.clear)
        )
        .overlay(
          Capsule(style: .continuous)
            .strokeBorder(
              isActive ? Theme.Colors.accentSecondary : Color.clear,
              lineWidth: 1
            )
        )
    }
    .buttonStyle(.plain)
  }

  // MARK: Difficulty selector

  private var difficultySelector: some View {
    HStack(spacing: Theme.Spacing.sm) {
      ForEach(MistakeTolerance.allCases) { tolerance in
        difficultyChip(for: tolerance)
      }
    }
  }

  private func difficultyChip(for tolerance: MistakeTolerance) -> some View {
    let isActive = tolerance == selectedMistakeTolerance
    return Button {
      SoundService.shared.play(.secondary)
      LogService.shared.log("leaderboard_difficulty_changed", [
        "mistakeTolerance": tolerance.rawValue,
      ])
      withAnimation(.easeOut(duration: 0.15)) {
        selectedMistakeTolerance = tolerance
      }
    } label: {
      Text(tolerance.brandLabel)
        .font(.crLabel)
        .textCase(.uppercase)
        .foregroundStyle(
          isActive ? Theme.Colors.textPrimary : Theme.Colors.textSecondary
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.sm + 2)
        .background(
          Capsule(style: .continuous)
            .fill(Theme.Colors.surface)
        )
        .overlay(
          Capsule(style: .continuous)
            .strokeBorder(
              isActive ? Theme.Colors.accent : Theme.Colors.border,
              lineWidth: isActive ? 2 : 1
            )
        )
    }
    .buttonStyle(.plain)
  }

  // MARK: Rank pill

  private var rankPill: AnyView? {
    guard gameCenter.isAuthenticated,
          let rank = gameCenter.ranks[currentKey] else { return nil }
    let label = String(localized: "YOU · RANK #\(rank.rank) OF \(rank.totalPlayers)")
    return AnyView(
      HStack {
        CRChip(verbatim: label, tone: .accent)
        Spacer()
      }
    )
  }

  // MARK: Score list

  @ViewBuilder
  private var scoreList: some View {
    let rows = displayedRows
    if rows.isEmpty {
      emptyState
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.xxxl)
    } else {
      VStack(spacing: Theme.Spacing.sm) {
        ForEach(rows) { row in
          ScoreRowView(row: row)
        }
      }
    }
  }

  // MARK: Empty state

  private var emptyState: some View {
    VStack(spacing: Theme.Spacing.md) {
      Image(systemName: "trophy")
        .font(.system(size: 48, weight: .regular))
        .foregroundStyle(Theme.Colors.textMuted)
      Text("No scores yet")
        .font(.crHeadline)
        .foregroundStyle(Theme.Colors.textPrimary)
      Text("Play a level to land on the board.")
        .font(.crBody)
        .foregroundStyle(Theme.Colors.textSecondary)
        .multilineTextAlignment(.center)
    }
  }

  // MARK: Global Ranking CTA

  private var globalRankingCTA: some View {
    VStack(spacing: Theme.Spacing.xs) {
      Button {
        SoundService.shared.play(.secondary)
        LogService.shared.log("leaderboard_global_ranking_pressed", [
          "gameType": selectedGameType.rawValue,
          "mistakeTolerance": selectedMistakeTolerance.rawValue,
          "gcAuthenticated": gameCenter.isAuthenticated,
        ])
        gameCenter.presentLeaderboard(
          gameType: selectedGameType,
          mistakeTolerance: selectedMistakeTolerance
        )
      } label: {
        HStack(spacing: Theme.Spacing.sm) {
          Image(systemName: "globe")
            .font(.system(size: 14, weight: .bold))
          Text("Global Ranking")
            .font(.crButtonLabel)
            .textCase(.uppercase)
        }
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.vertical, Theme.Spacing.md)
        .padding(.horizontal, Theme.Spacing.xl)
        .background(
          Capsule(style: .continuous)
            .fill(Theme.Colors.surfaceElevated)
        )
      }
      .buttonStyle(.plain)
      .disabled(!gameCenter.isAuthenticated)
      .opacity(gameCenter.isAuthenticated ? 1.0 : 0.5)

      if !gameCenter.isAuthenticated {
        Text("Sign in to Game Center to see the global ranking")
          .font(.crCaption)
          .foregroundStyle(Theme.Colors.textSecondary)
          .multilineTextAlignment(.center)
      }
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: Refresh

  private func refreshAll() async {
    await gameCenter.refreshRank(
      for: selectedGameType,
      mistakeTolerance: selectedMistakeTolerance
    )
    await gameCenter.refreshTopEntries(
      for: selectedGameType,
      mistakeTolerance: selectedMistakeTolerance
    )
  }
}

// MARK: - Score row

private struct ScoreRowView: View {
  let row: DisplayRow

  private var rankColor: Color {
    if row.isLocalPlayer { return Theme.Colors.accent }
    if row.rank == 1 { return Theme.Colors.pro }
    return Theme.Colors.textSecondary
  }

  private var borderColor: Color {
    if row.isLocalPlayer { return Theme.Colors.accent }
    if row.rank == 1 { return Theme.Colors.pro.opacity(0.6) }
    return Theme.Colors.border
  }

  private var borderWidth: CGFloat {
    row.isLocalPlayer || row.rank == 1 ? 2 : 1
  }

  var body: some View {
    HStack(spacing: Theme.Spacing.md) {
      Text(String(format: "%02d", row.rank))
        .font(.crLabel)
        .foregroundStyle(rankColor)
        .frame(width: 28, alignment: .leading)

      if let name = row.displayName {
        Text(name)
          .font(.crBody)
          .foregroundStyle(Theme.Colors.textPrimary)
          .lineLimit(1)
          .truncationMode(.tail)
      }

      if row.rank == 1 {
        Image(systemName: "crown.fill")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(Theme.Colors.pro)
      }

      Spacer(minLength: Theme.Spacing.sm)

      Text(row.formattedScore)
        .font(.crTitle)
        .foregroundStyle(row.rank == 1 ? Theme.Colors.pro : Theme.Colors.textPrimary)
    }
    .padding(.vertical, Theme.Spacing.md)
    .padding(.horizontal, Theme.Spacing.lg)
    .background(
      RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        .fill(Theme.Colors.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        .strokeBorder(borderColor, lineWidth: borderWidth)
    )
  }
}

#Preview {
  LeaderboardView()
}
