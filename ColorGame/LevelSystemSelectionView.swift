import SwiftUI

// MARK: - View-layer brand labels & tones

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

  var difficultyTone: Color {
    switch self {
    case .easy: Theme.Colors.success
    case .normal: Theme.Colors.pro
    case .hard: Theme.Colors.danger
    }
  }

  var totalLivesCount: Int {
    switch self {
    case .easy: 5
    case .normal: 3
    case .hard: 1
    }
  }
}

// MARK: - LevelSystemSelectionView

struct LevelSystemSelectionView: View {
  @StateObject private var levelRun: LevelRun = {
    let run = LevelRun()
    run.mistakeTolerance = .easy
    return run
  }()
  @StateObject private var leaderboardStore = LeaderboardStore.shared

  @AppStorage("cr.preferredGameType")
  private var storedGameTypeRaw: String = GameType.colorOnly.rawValue

  @State private var currentStep: SelectionStep = .gameType
  @State private var isGameViewPresented = false
  @State private var selectedMistakeTolerance: MistakeTolerance? = .easy
  @Binding var isPresented: Bool

  private var selectedGameType: GameType {
    GameType(rawValue: storedGameTypeRaw) ?? .colorOnly
  }

  enum SelectionStep {
    case gameType
    case mistakeTolerance
  }

  private var shouldRecommendColorOnly: Bool {
    MistakeTolerance.allCases.allSatisfy { tolerance in
      leaderboardStore.getScores(
        gameType: .colorAndText,
        mistakeTolerance: tolerance
      ).isEmpty
    }
  }

  var body: some View {
    ZStack {
      Theme.Colors.background.ignoresSafeArea()

      VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
        CRSectionHeader(
          title: currentStep == .gameType ? "Pick a Mode" : "How Hard?",
          step: currentStep == .gameType ? "Step 1/2" : "Step 2/2",
          onBack: handleBack
        )
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.lg)

        if currentStep == .gameType {
          gameTypeSelectionView
            .padding(.horizontal, Theme.Spacing.lg)
            .transition(.opacity)
        } else {
          mistakeToleranceSelectionView
            .padding(.horizontal, Theme.Spacing.lg)
            .transition(.opacity)
        }

        Spacer(minLength: 0)

        ctaButton
          .padding(.horizontal, Theme.Spacing.lg)
          .padding(.bottom, Theme.Spacing.lg)
      }
    }
    .preferredColorScheme(.dark)
    .onAppear {
      levelRun.gameType = selectedGameType
    }
    #if !os(macOS)
    .fullScreenCover(isPresented: $isGameViewPresented) {
      LevelGameView(levelRun: levelRun)
    }
    #else
    .sheet(isPresented: $isGameViewPresented) {
      LevelGameView(levelRun: levelRun)
    }
    #endif
  }

  // MARK: Step 1 — Pick a Mode

  private var gameTypeSelectionView: some View {
    VStack(spacing: Theme.Spacing.md) {
      ForEach(GameType.allCases) { gameType in
        modeCard(for: gameType)
      }
    }
  }

  private func modeCard(for gameType: GameType) -> some View {
    let isSelected = selectedGameType == gameType
    let isRecommended = gameType == .colorOnly && shouldRecommendColorOnly
    return Button {
      withAnimation(.easeOut(duration: 0.15)) {
        storedGameTypeRaw = gameType.rawValue
        levelRun.gameType = gameType
      }
    } label: {
      HStack(alignment: .center, spacing: Theme.Spacing.md) {
        ModeSwatchGrid(showsLabels: gameType == .colorAndText)
          .frame(width: 76, height: 76)

        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          Text(modeTitle(for: gameType))
            .font(.crHeadline)
            .foregroundStyle(Theme.Colors.textPrimary)
          Text(modeDescription(for: gameType))
            .font(.crBody)
            .foregroundStyle(Theme.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 0)
      }
      .padding(.vertical, Theme.Spacing.md)
      .padding(.horizontal, Theme.Spacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
          .fill(Theme.Colors.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
          .strokeBorder(
            isSelected ? Theme.Colors.accentSecondary : Theme.Colors.border,
            lineWidth: isSelected ? 1.5 : 1
          )
      )
      .overlay(alignment: .topTrailing) {
        if isRecommended {
          CRChip(title: "Recommended to start", tone: .accent)
            .background(
              Capsule(style: .continuous)
                .fill(Theme.Colors.background)
            )
            .offset(x: -Theme.Spacing.lg, y: -12)
        }
      }
    }
    .buttonStyle(.plain)
  }

  private func modeTitle(for gameType: GameType) -> LocalizedStringKey {
    switch gameType {
    case .colorOnly: "Color ONLY"
    case .colorAndText: "Color and Text"
    }
  }

  private func modeDescription(for gameType: GameType) -> LocalizedStringKey {
    switch gameType {
    case .colorOnly:
      "A color is called. Tap any square that's not that color."
    case .colorAndText:
      "Each square has a color and a word. Tap only when neither matches the called color."
    }
  }

  // MARK: Step 2 — How Hard?

  private var mistakeToleranceSelectionView: some View {
    VStack(spacing: Theme.Spacing.md) {
      ForEach(MistakeTolerance.allCases) { tolerance in
        difficultyCard(for: tolerance)
      }
    }
  }

  private func difficultyCard(for tolerance: MistakeTolerance) -> some View {
    let isSelected = selectedMistakeTolerance == tolerance
    let tone = tolerance.difficultyTone
    return Button {
      withAnimation(.easeOut(duration: 0.15)) {
        selectedMistakeTolerance = tolerance
        levelRun.mistakeTolerance = tolerance
      }
    } label: {
      HStack(alignment: .center, spacing: Theme.Spacing.md) {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(tone)
          .frame(width: 4, height: 36)

        VStack(alignment: .leading, spacing: 2) {
          Text(tolerance.brandLabel)
            .font(.crHeadline)
            .foregroundStyle(Theme.Colors.textPrimary)
          Text(difficultyDescription(for: tolerance))
            .font(.crBody)
            .foregroundStyle(Theme.Colors.textSecondary)
        }

        Spacer(minLength: 0)

        HeartsRow(count: tolerance.totalLivesCount)
      }
      .padding(.vertical, Theme.Spacing.md)
      .padding(.horizontal, Theme.Spacing.lg)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
          .fill(Theme.Colors.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
          .strokeBorder(
            isSelected ? tone : Theme.Colors.border,
            lineWidth: isSelected ? 1.5 : 1
          )
      )
    }
    .buttonStyle(.plain)
  }

  private func difficultyDescription(for tolerance: MistakeTolerance) -> LocalizedStringKey {
    switch tolerance {
    case .easy: "5 lives - good to start"
    case .normal: "3 lives - the real deal"
    case .hard: "1 life - 1 mistake, game over"
    }
  }

  // MARK: CTA

  @ViewBuilder
  private var ctaButton: some View {
    switch currentStep {
    case .gameType:
      Button("Continue") {
        advanceToDifficulty()
      }
      .buttonStyle(.crPrimary)
    case .mistakeTolerance:
      Button("Let's go") {
        startLevelRun()
      }
      .buttonStyle(.crPrimary)
      .disabled(selectedMistakeTolerance == nil)
      .opacity(selectedMistakeTolerance == nil ? 0.5 : 1.0)
    }
  }

  // MARK: Navigation

  private func handleBack() {
    switch currentStep {
    case .gameType:
      isPresented = false
    case .mistakeTolerance:
      withAnimation(.easeInOut(duration: 0.25)) {
        currentStep = .gameType
      }
    }
  }

  private func advanceToDifficulty() {
    withAnimation(.easeInOut(duration: 0.25)) {
      currentStep = .mistakeTolerance
      if selectedMistakeTolerance == nil {
        selectedMistakeTolerance = .easy
        levelRun.mistakeTolerance = .easy
      }
    }
  }

  private func startLevelRun() {
    guard let mistakeTolerance = selectedMistakeTolerance else { return }
    levelRun.startRun(gameType: selectedGameType, mistakeTolerance: mistakeTolerance)
    isGameViewPresented = true
  }
}

// MARK: - Mode swatch grid

private struct ModeSwatchGrid: View {
  let showsLabels: Bool

  private struct Tile: Identifiable {
    let id = UUID()
    let color: Color
    let label: LocalizedStringKey
  }

  /// Tiles for the Color and Text variant — each label intentionally
  /// mismatches its tile color to illustrate the gameplay quirk.
  private var tiles: [Tile] {
    [
      .init(color: .red, label: "BLUE"),
      .init(color: .blue, label: "RED"),
      .init(color: .green, label: "GREEN"),
      .init(color: .yellow, label: "RED"),
    ]
  }

  var body: some View {
    let columns = [
      GridItem(.flexible(), spacing: Theme.Spacing.xs),
      GridItem(.flexible(), spacing: Theme.Spacing.xs),
    ]
    LazyVGrid(columns: columns, spacing: Theme.Spacing.xs) {
      ForEach(tiles) { tile in
        ZStack {
          RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
            .fill(tile.color)
          if showsLabels {
            Text(tile.label)
              .font(.crPill)
              .foregroundStyle(Theme.Colors.textPrimary)
              .lineLimit(1)
              .minimumScaleFactor(0.7)
          }
        }
        .aspectRatio(1, contentMode: .fit)
      }
    }
  }
}

// MARK: - Hearts row

private struct HeartsRow: View {
  let count: Int

  var body: some View {
    HStack(spacing: 3) {
      ForEach(0..<max(0, count), id: \.self) { _ in
        Image(systemName: "heart.fill")
          .font(.system(size: 13, weight: .bold))
          .foregroundStyle(Theme.Colors.danger)
      }
    }
  }
}

#Preview {
  LevelSystemSelectionView(isPresented: .constant(true))
}
