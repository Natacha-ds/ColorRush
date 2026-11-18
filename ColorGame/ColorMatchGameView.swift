import Combine
import SwiftUI

// MARK: - Game view

struct ColorMatchGameView: View {
  @StateObject private var game = ColorMatchGame()
  @StateObject private var leaderboardStore = LeaderboardStore.shared
  @Environment(\.scenePhase) private var scenePhase
  @Environment(\.dismiss) private var dismiss

  @State private var lastTick: Date?
  @State private var hasRecordedResult = false
  @State private var isNewBest = false
  @State private var previousBest = 0

  private let ticker = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

  var body: some View {
    ZStack {
      if game.isOver {
        ColorMatchGameOverView(
          score: game.score,
          best: bestScore,
          isNewBest: isNewBest,
          onRetry: restart,
          onHome: {
            NotificationCenter.default.post(
              name: NSNotification.Name("DismissToHome"),
              object: nil
            )
          }
        )
        .transition(.opacity)
      } else {
        playingScreen
      }
    }
    .preferredColorScheme(.dark)
    .onReceive(ticker) { now in
      guard scenePhase == .active, !game.isOver else {
        lastTick = nil
        return
      }
      if let lastTick {
        // Cap dt so a hitch (e.g. returning from background) never eats a card.
        game.tick(min(now.timeIntervalSince(lastTick), 0.1))
      }
      lastTick = now
    }
    .onChange(of: game.isOver) { _, isOver in
      if isOver { finishRun() }
    }
    .onAppear {
      LogService.shared.log("run_started", ["gameType": GameType.colorMatch.rawValue])
    }
  }

  // MARK: Playing screen

  private var playingScreen: some View {
    ZStack {
      game.card.background.color
        .ignoresSafeArea()
        .animation(nil, value: game.card)

      VStack(spacing: Theme.Spacing.lg) {
        header
          .padding(.horizontal, Theme.Spacing.xl)
          .padding(.top, Theme.Spacing.lg)

        countdownBar
          .padding(.horizontal, Theme.Spacing.xl)

        Spacer()

        Text(game.card.word.name)
          .font(.crScoreHero)
          .foregroundStyle(Color.white)
          .shadow(color: .black.opacity(0.55), radius: 0, x: 0, y: 3)
          .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
          .minimumScaleFactor(0.5)
          .lineLimit(1)
          .padding(.horizontal, Theme.Spacing.xl)
          .accessibilityLabel(game.card.word.name)

        Spacer()

        answerButtons
          .padding(.horizontal, Theme.Spacing.xl)
          .padding(.bottom, Theme.Spacing.xl)
      }
    }
  }

  private var header: some View {
    HStack(alignment: .center) {
      Button {
        SoundService.shared.play(.secondary)
        LogService.shared.log("run_abandoned", [
          "gameType": GameType.colorMatch.rawValue,
          "score": game.score,
          "reason": "back_button",
        ])
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.system(size: 18, weight: .bold))
      }
      .buttonStyle(.crIcon)
      .accessibilityLabel("Back")

      Spacer()

      VStack(alignment: .trailing, spacing: 0) {
        Text("SCORE")
          .font(.crLabel)
          .textCase(.uppercase)
          .foregroundStyle(Color.white.opacity(0.85))
        Text("\(game.score)")
          .font(.crTitle)
          .foregroundStyle(Color.white)
      }
      .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
    }
  }

  private var countdownBar: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule(style: .continuous)
          .fill(Color.black.opacity(0.35))
        Capsule(style: .continuous)
          .fill(Color.white)
          .frame(width: geo.size.width * CGFloat(game.progress))
      }
    }
    .frame(height: 10)
    .accessibilityHidden(true)
  }

  private var answerButtons: some View {
    HStack(spacing: Theme.Spacing.lg) {
      answerButton(isSame: false, systemImage: "xmark", tint: Theme.Colors.danger)
        .accessibilityLabel("Different color")
      answerButton(isSame: true, systemImage: "checkmark", tint: Theme.Colors.success)
        .accessibilityLabel("Same color")
    }
  }

  private func answerButton(isSame: Bool, systemImage: String, tint: Color) -> some View {
    Button {
      handleAnswer(isSame: isSame)
    } label: {
      Image(systemName: systemImage)
        .font(.system(size: 44, weight: .black))
        .foregroundStyle(Color.white)
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(
          RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
            .fill(tint)
        )
        .overlay(
          RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
            .strokeBorder(Color.white.opacity(0.6), lineWidth: 3)
        )
        .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)
    }
    .buttonStyle(.plain)
  }

  // MARK: Actions

  private var bestScore: Int {
    max(previousBest, game.score)
  }

  private func handleAnswer(isSame: Bool) {
    let correct = game.answer(isSame: isSame)
    LogService.shared.log("match_answer", [
      "correct": correct,
      "score": game.score,
    ])
    if correct {
      HapticsService.shared.lightImpact()
    } else {
      HapticsService.shared.heavyImpact()
    }
  }

  private func finishRun() {
    guard !hasRecordedResult else { return }
    hasRecordedResult = true
    let score = game.score
    let best = leaderboardStore
      .getScores(gameType: .colorMatch, mistakeTolerance: nil)
      .first?.score ?? 0
    previousBest = best
    isNewBest = score > best
    if score > 0 {
      leaderboardStore.addScore(score, gameType: .colorMatch, mistakeTolerance: nil)
      GameCenterService.shared.submitScore(
        score,
        gameType: .colorMatch,
        mistakeTolerance: nil
      )
    }
    HapticsService.shared.heavyImpact()
    var reason = "wrong_answer"
    if case .over(.timeout) = game.phase { reason = "timeout" }
    LogService.shared.log("run_ended", [
      "gameType": GameType.colorMatch.rawValue,
      "score": score,
      "reason": reason,
    ])
  }

  private func restart() {
    SoundService.shared.play(.main)
    hasRecordedResult = false
    isNewBest = false
    lastTick = nil
    game.reset()
    LogService.shared.log("run_started", [
      "gameType": GameType.colorMatch.rawValue,
      "retry": true,
    ])
  }
}

// MARK: - Game over

struct ColorMatchGameOverView: View {
  let score: Int
  let best: Int
  let isNewBest: Bool
  let onRetry: () -> Void
  let onHome: () -> Void

  var body: some View {
    ZStack {
      Theme.Colors.background.ignoresSafeArea()
      Theme.Gradient.gameOverWash.ignoresSafeArea()

      VStack(spacing: Theme.Spacing.lg) {
        Spacer()

        VStack(spacing: Theme.Spacing.sm) {
          Text("Game Over")
            .font(.crDisplay)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.danger)
          if isNewBest {
            CRChip(title: "New best!", tone: .accent)
          }
        }

        VStack(spacing: Theme.Spacing.xs) {
          Text("Colors passed")
            .font(.crLabel)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textSecondary)
          Text("\(score)")
            .font(.crScoreHero)
            .foregroundStyle(Theme.Colors.textPrimary)
          Text("Best: \(best)")
            .font(.crBody)
            .foregroundStyle(Theme.Colors.pro)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.Spacing.lg)
        .background(
          RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
            .fill(Theme.Colors.surface)
        )
        .padding(.horizontal, Theme.Spacing.xl)

        Spacer()

        Button(action: onRetry) {
          HStack(spacing: Theme.Spacing.sm) {
            Image("CRRetry")
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 18, height: 18)
            Text("Try Again")
          }
        }
        .buttonStyle(.crPrimary)
        .padding(.horizontal, Theme.Spacing.xl)

        ScoreShareLink(
          score: score,
          gameType: .colorMatch,
          mistakeTolerance: nil,
          source: .gameOver,
          accessibilityLabel: "Share my run score"
        ) {
          HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "square.and.arrow.up")
              .font(.system(size: 14, weight: .bold))
            Text("SHARE")
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
        .disabled(score <= 0)
        .opacity(score <= 0 ? 0.5 : 1)

        Button {
          SoundService.shared.play(.secondary)
          onHome()
        } label: {
          Text("Back to Home")
            .font(.crButtonLabel)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.bottom, Theme.Spacing.lg)
      }
    }
  }
}

#Preview {
  ColorMatchGameView()
}

#Preview("Game over") {
  ColorMatchGameOverView(score: 24, best: 31, isNewBest: false, onRetry: {}, onHome: {})
}
