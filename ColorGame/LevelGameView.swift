import SwiftUI
#if canImport(UIKit)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

enum LevelFailureReason {
  case maxMistakes
  case insufficientScore
}

private let crTileGridSpacing: CGFloat = Theme.Spacing.lg
private let crTileSide: CGFloat = 150

// Tap burst (correct-tap only): UIKit CAEmitterLayer-driven spark burst
// emanating from BEHIND the tapped tile, base color derived from the tile.
// Canvas matches the tile grid exactly so it never forces the parent VStack
// wider than the screen. CAEmitterLayer particles can still fly outside the
// canvas bounds — both the host UIView and the emitter layer keep
// masksToBounds = false (default), so nothing clips the visible burst.
private let crBurstAreaSize: CGFloat = crTileSide * 2 + crTileGridSpacing
private let crBurstOriginEdgeOffset: CGFloat = 0

private struct CRSparkBurstSpec: Equatable, Identifiable {
  let id: Int
  let origin: CGPoint
  let baseColor: Color
  let particleCount: Int
}

private let crSparkEmitWindow: TimeInterval = 0.05

#if canImport(UIKit)

/// Programmatic radial-gradient spark image (white center → transparent edge),
/// generated once at first access and reused as the contents of every emitter
/// cell. Avoids shipping an asset.
private enum CRSparkAssets {
  static let image: CGImage = {
    let size = CGSize(width: 24, height: 24)
    let renderer = UIGraphicsImageRenderer(size: size)
    let uiImage = renderer.image { ctx in
      let cg = ctx.cgContext
      let center = CGPoint(x: size.width / 2, y: size.height / 2)
      let cs = CGColorSpaceCreateDeviceRGB()
      let colors = [
        UIColor.white.cgColor,
        UIColor.white.withAlphaComponent(0.7).cgColor,
        UIColor.white.withAlphaComponent(0.0).cgColor,
      ] as CFArray
      if let gradient = CGGradient(
        colorsSpace: cs,
        colors: colors,
        locations: [0, 0.4, 1]
      ) {
        cg.drawRadialGradient(
          gradient,
          startCenter: center, startRadius: 0,
          endCenter: center, endRadius: size.width / 2,
          options: []
        )
      }
    }
    return uiImage.cgImage ?? UIImage().cgImage!
  }()
}

/// SwiftUI wrapper around a host UIView whose layer hosts ephemeral
/// CAEmitterLayers — one per burst. Each new spec (identified by `id`)
/// fires a new emitter with the snippet's parameters, then auto-removes
/// after particles die. Supports a queue so multiple simultaneous bursts
/// (e.g., streak celebration) fire in parallel.
private struct CRSparkEmitterView: UIViewRepresentable {
  let bursts: [CRSparkBurstSpec]
  let clearToken: Int

  func makeCoordinator() -> Coordinator { Coordinator() }

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false
    view.layer.masksToBounds = false
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {
    // Clear all in-flight emitters when the parent bumps the clear token
    // (e.g., between levels) so particles don't leak across level transitions.
    if context.coordinator.lastClearToken != clearToken {
      context.coordinator.lastClearToken = clearToken
      uiView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    }

    let unseen = bursts.filter { $0.id > context.coordinator.lastSeen }
    guard !unseen.isEmpty else { return }
    if let maxId = unseen.map(\.id).max() {
      context.coordinator.lastSeen = maxId
    }
    for spec in unseen {
      Self.fireBurst(spec: spec, in: uiView)
    }
  }

  private static func fireBurst(spec: CRSparkBurstSpec, in container: UIView) {
    let emitter = CAEmitterLayer()
    emitter.frame = container.bounds
    emitter.emitterPosition = spec.origin
    emitter.emitterSize = .zero
    emitter.emitterShape = .point
    emitter.emitterMode = .surface
    emitter.renderMode = .additive

    let cell = CAEmitterCell()
    cell.contents = CRSparkAssets.image
    cell.name = "Spark"
    cell.birthRate = Float(Double(spec.particleCount) / crSparkEmitWindow)
    cell.lifetime = 3.0
    cell.velocity = 55.0
    cell.velocityRange = 280.0
    cell.xAcceleration = 0.0
    cell.yAcceleration = 50.0
    cell.emissionLatitude = 0.0
    cell.emissionLongitude = 0.0
    cell.emissionRange = 360.0 * (.pi / 180.0)
    cell.spin = 65.0 * (.pi / 180.0)
    cell.spinRange = 314.0 * (.pi / 180.0)
    cell.scale = 0.113
    cell.scaleSpeed = -0.030
    cell.alphaSpeed = 0.42

    let uic = UIColor(spec.baseColor).withAlphaComponent(0.39)
    cell.color = uic.cgColor
    cell.redRange = 0.3
    cell.greenRange = 0.21
    cell.blueRange = 0.6

    emitter.emitterCells = [cell]
    container.layer.addSublayer(emitter)

    // One-shot burst: stop emitting after a beat, then remove the layer
    // once existing particles have died out.
    DispatchQueue.main.asyncAfter(deadline: .now() + crSparkEmitWindow) { [weak emitter] in
      emitter?.birthRate = 0
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak emitter] in
      emitter?.removeFromSuperlayer()
    }
  }

  final class Coordinator {
    var lastSeen: Int = -1
    var lastClearToken: Int = 0
  }
}

#endif

struct LevelGameView: View {
  @ObservedObject var levelRun: LevelRun
  @Environment(\.dismiss) private var dismiss
  @State private var showFinalWinView = false

  // Game state
  @State private var announcedColor: Color = .red
  @State private var tiles: [Color] = [] // For Color Only mode
  @State private var tilesWithText: [Tile] = [] // For Color + Text mode
  @State private var previousTiles: [Color] = []
  @State private var previousTilesWithText: [Tile] = []
  @State private var showingErrorFlash = false
  @State private var isGameActive = false

  // Level timer state
  @State private var timeRemaining: Double = 30.0
  @State private var gameTimer: Timer?
  @State private var isGameSessionActive = false
  @State private var backgroundTime: Date?

  // Round timer state (for levels with time limits)
  @State private var roundTimeRemaining: Double = 0
  @State private var roundTimer: Timer?
  @State private var isRoundTimerActive = false

  // Pending deferred work — superseded on re-schedule, cancelled in endGameSession()
  @State private var pendingNextRound: DispatchWorkItem?
  @State private var pendingIntroDismiss: DispatchWorkItem?
  @State private var pendingActivation: DispatchWorkItem?

  // Game over state
  @State private var isLevelComplete = false
  @State private var isLevelFailed = false
  @State private var failedReason: LevelFailureReason = .insufficientScore

  // Streak animation state
  @State private var showStreakAnimation = false
  @State private var streakDisplayCount = 0

  // Level intro pop-in state
  @State private var showLevelIntro = false

  // Burst overlay state (purely visual). A new spark burst is appended to
  // `sparkBursts` whenever the game-logic side reports a correct answer
  // (observed via `levelRun.levelCorrectAnswers` change), at the canvas-space
  // position captured from the tap gesture. Particle count scales with
  // `levelRun.currentStreak` (capped). On a streak-bonus event, four bursts
  // fire simultaneously at the four tile centers.
  @State private var sparkBursts: [CRSparkBurstSpec] = []
  @State private var sparkCounter: Int = 0
  @State private var sparkClearToken: Int = 0
  @State private var lastTappedIndex: Int? = nil
  @State private var pendingBurstOrigin: CGPoint? = nil

  // Color repeat tracking
  @State private var recentAnnouncedColors: [Color] = []

  // Tile position tracking (prevent same position being correct more than 4
  // times in a row)
  // Key: tile position index (0-3), Value: consecutive times this position was correct
  @State private var consecutiveCorrectByPosition: [Int: Int] = [:]

  // Services
  @State private var speechService = SpeechService()
  private let hapticsService = HapticsService.shared

  // Color palette
  private let colorPalette: [Color] = [.red, .blue, .green, .yellow]

  var body: some View {
    NavigationView {
      ZStack {
        // Pure black background — design-system token replaces the v1
        // per-level cosmic image; the tap burst animation provides the
        // dynamic visual element on the active gameplay state.
        Theme.Colors.background
          .ignoresSafeArea()

        if isLevelComplete {
          // Check if this is the final level (10) - show special win screen
          if levelRun.currentLevel == 10 {
            FinalWinView(
              levelRun: levelRun,
              onPlayHarder: {
                // Complete the level and save score
                levelRun.completeLevel()
                LeaderboardStore.shared.addScore(
                  levelRun.globalScore,
                  gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                )
                GameCenterService.shared.submitScore(
                  levelRun.globalScore,
                  gameType: levelRun.gameType,
                  mistakeTolerance: levelRun.mistakeTolerance
                )
                // Reset everything
                levelRun.resetRunStats()
                levelRun.currentLevel = 1
                levelRun.isActive = false
                // Maybe show an interstitial, then dismiss back to the
                // selection funnel.
                AdsService.shared.showInterstitialIfReady {
                  dismiss()
                }
              },
              onSeeLeaderboard: {
                // Complete the level and save score
                levelRun.completeLevel()
                LeaderboardStore.shared.addScore(
                  levelRun.globalScore,
                  gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                )
                GameCenterService.shared.submitScore(
                  levelRun.globalScore,
                  gameType: levelRun.gameType,
                  mistakeTolerance: levelRun.mistakeTolerance
                )
                // Reset everything
                levelRun.resetRunStats()
                levelRun.currentLevel = 1
                levelRun.isActive = false
                // Maybe show an interstitial first, then dismiss + switch tab.
                AdsService.shared.showInterstitialIfReady {
                  dismiss()
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    NotificationCenter.default.post(
                      name: NSNotification.Name("SwitchToLeaderboard"),
                      object: nil
                    )
                  }
                }
              }
            )
          } else {
            LevelCompleteView(
              levelRun: levelRun,
              onNextLevel: {
                levelRun.completeLevel()
                if levelRun.isCompleted {
                  // Save score to leaderboard when run completes
                  LeaderboardStore.shared.addScore(
                    levelRun.globalScore,
                    gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                  )
                  GameCenterService.shared.submitScore(
                    levelRun.globalScore,
                    gameType: levelRun.gameType,
                    mistakeTolerance: levelRun.mistakeTolerance
                  )
                  // Show run complete screen
                  dismiss()
                } else {
                  AdsService.shared.showInterstitialIfReady {
                    startNewLevel()
                  }
                }
              },
              onBackToHome: {
                let totalScore = levelRun.globalScore + levelRun
                  .levelPositivePoints
                if totalScore > 0 {
                  LeaderboardStore.shared.addScore(
                    totalScore,
                    gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                  )
                  GameCenterService.shared.submitScore(
                    totalScore,
                    gameType: levelRun.gameType,
                    mistakeTolerance: levelRun.mistakeTolerance
                  )
                }
                levelRun.resetRunStats()
                levelRun.currentLevel = 1
                levelRun.isActive = false
                AdsService.shared.showInterstitialIfReady {
                  NotificationCenter.default.post(
                    name: NSNotification.Name("DismissToHome"),
                    object: nil
                  )
                }
              }
            )
          }
        } else if isLevelFailed {
          // Show LevelGameOverView for run-ending failures, LevelFailedView for
          // insufficient score
          if failedReason == .maxMistakes {
            LevelGameOverView(
              levelRun: levelRun,
              failedReason: failedReason,
              onContinueWithExtraLife: {
                // Reward earned: grant the life and resume the level fresh.
                // The flag `hasUsedRewardedRevive` was already flipped on tap
                // (anti-abuse), so the button is gone for the rest of the run.
                levelRun.grantExtraLife()
                // startNewLevel guards on isLevelFailed || isLevelComplete,
                // and resets both flags + level stats + restarts the timer.
                startNewLevel()
              },
              onBackToHome: {
                // Save score to leaderboard if positive when run ends (game
                // over)
                let totalScore = levelRun.globalScore + levelRun
                  .levelPositivePoints
                if totalScore > 0 {
                  LeaderboardStore.shared.addScore(
                    totalScore,
                    gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                  )
                  GameCenterService.shared.submitScore(
                    totalScore,
                    gameType: levelRun.gameType,
                    mistakeTolerance: levelRun.mistakeTolerance
                  )
                }
                // Reset everything when going back to home after game over
                levelRun.resetRunStats()
                levelRun.currentLevel = 1
                levelRun.isActive = false
                AdsService.shared.showInterstitialIfReady {
                  NotificationCenter.default.post(
                    name: NSNotification.Name("DismissToHome"),
                    object: nil
                  )
                }
              }
            )
          } else {
            LevelFailedView(
              levelRun: levelRun,
              failedReason: failedReason,
              onRetry: {
                AdsService.shared.showInterstitialIfReady {
                  startNewLevel()
                }
              },
              onBackToHome: {
                // Save score to leaderboard if positive when run ends
                let totalScore = levelRun.globalScore + levelRun
                  .levelPositivePoints
                if totalScore > 0 {
                  LeaderboardStore.shared.addScore(
                    totalScore,
                    gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance
                  )
                  GameCenterService.shared.submitScore(
                    totalScore,
                    gameType: levelRun.gameType,
                    mistakeTolerance: levelRun.mistakeTolerance
                  )
                }
                levelRun.resetRunStats()
                levelRun.currentLevel = 1
                levelRun.isActive = false
                AdsService.shared.showInterstitialIfReady {
                  NotificationCenter.default.post(
                    name: NSNotification.Name("DismissToHome"),
                    object: nil
                  )
                }
              }
            )
          }
        } else {
          // Active Game Screen
          ZStack {
            VStack(spacing: Theme.Spacing.lg) {
              // Top HUD: back arrow + SCORE on left, hearts pill on right
              HStack(alignment: .top, spacing: Theme.Spacing.md) {
                Button(action: {
                  endGameSession()
                  let totalScore = levelRun.globalScore + levelRun
                    .levelPositivePoints
                  if totalScore > 0 {
                    LeaderboardStore.shared.addScore(
                      totalScore,
                      gameType: levelRun.gameType,
                      mistakeTolerance: levelRun.mistakeTolerance
                    )
                    GameCenterService.shared.submitScore(
                      totalScore,
                      gameType: levelRun.gameType,
                      mistakeTolerance: levelRun.mistakeTolerance
                    )
                  }
                  levelRun.resetRunStats()
                  levelRun.currentLevel = 1
                  levelRun.isActive = false
                  // Dismiss to the Home tab in a single animation by collapsing
                  // the LevelSystemSelectionView underneath us. SwiftUI will
                  // dismantle this LevelGameView automatically as the parent
                  // fullScreenCover goes away — calling dismiss() here would
                  // produce a visible flash of the selection screen.
                  AdsService.shared.showInterstitialIfReady {
                    NotificationCenter.default.post(
                      name: NSNotification.Name("DismissToHome"),
                      object: nil
                    )
                  }
                }) {
                  Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .bold))
                }
                .buttonStyle(.crIcon)

                VStack(alignment: .leading, spacing: 2) {
                  Text("SCORE")
                    .font(.crLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(Theme.Colors.textSecondary)
                  Text("\(levelRun.currentScore)")
                    .font(.crTitle)
                    .foregroundStyle(Theme.Colors.textPrimary)
                }
                .padding(.top, Theme.Spacing.sm)

                Spacer()

                CRHeartsPill(
                  remaining: levelRun.remainingLives,
                  total: levelRun.mistakeTolerance.totalLives
                )
                .padding(.top, Theme.Spacing.md)

                if levelRun.shouldShowDevTools, !levelRun.isCompleted {
                  Button(action: {
                    SoundService.shared.play(.secondary)
                    LogService.shared.log("level_skipped", [
                      "level": levelRun.currentLevel,
                    ])
                    levelRun.skipToNextLevel()
                    startNewLevel()
                  }) {
                    Text("Skip")
                      .font(.crCaption)
                      .foregroundStyle(Theme.Colors.warning)
                      .padding(.horizontal, Theme.Spacing.sm)
                      .padding(.vertical, Theme.Spacing.xs)
                      .background(
                        Capsule(style: .continuous)
                          .strokeBorder(
                            Theme.Colors.warning.opacity(0.4),
                            lineWidth: 1
                          )
                      )
                  }
                  .padding(.top, Theme.Spacing.md)
                }
              }

              // TARGET label + progress bar
              VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("TARGET: \(levelRun.getRequiredScore())")
                  .font(.crLabel)
                  .textCase(.uppercase)
                  .foregroundStyle(Theme.Colors.accentSecondary)
                CRProgressBar(progress: targetProgress)
                  .animation(.easeOut, value: levelRun.currentScore)
              }

              Spacer(minLength: Theme.Spacing.lg)

              // LEVEL XX title
              Text("LEVEL \(levelRun.currentLevel)")
                .font(.crDisplay)
                .textCase(.uppercase)
                .foregroundStyle(Theme.Colors.textPrimary)

              // Hourglass + countdown (number only, large, white — turns danger under 5s)
              HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "hourglass")
                  .font(.system(size: 22, weight: .bold))
                  .foregroundStyle(Theme.Colors.accentSecondary)
                Text(verbatim: "\(Int(timeRemaining.rounded(.up)))")
                  .font(.crTitle)
                  .foregroundStyle(
                    timeRemaining <= 5 ? Theme.Colors.danger : Theme.Colors.textPrimary
                  )
              }

              Spacer(minLength: Theme.Spacing.lg)

              // Round-time progress bar (conditional)
              if let levelConfig = levelRun.currentLevelConfig,
                 levelConfig.hasTimeLimit, !levelConfig.isNonPunitiveRefresh
              {
                let timePerResponse = levelConfig.timePerResponse ?? 1.0
                let roundProgress = max(0.0, min(1.0, roundTimeRemaining / timePerResponse))
                let isLow = roundTimeRemaining <= timePerResponse * 0.3
                GeometryReader { rg in
                  ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                      .fill(Theme.Colors.surfaceElevated)
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                      .fill(isLow ? Theme.Colors.danger : Theme.Colors.success)
                      .frame(width: rg.size.width * roundProgress)
                  }
                }
                .frame(height: 3)
                .padding(.horizontal, Theme.Spacing.lg)
                .animation(.linear(duration: 0.1), value: roundTimeRemaining)
              }

              // 2x2 tile grid wrapped in a fixed-size container with the
              // spark emitter BEHIND the tiles so the burst emanates from
              // behind the tapped tile.
              ZStack {
                #if canImport(UIKit)
                CRSparkEmitterView(bursts: sparkBursts, clearToken: sparkClearToken)
                  .frame(width: crBurstAreaSize, height: crBurstAreaSize)
                  .allowsHitTesting(false)
                  .zIndex(0)
                #endif

                VStack(spacing: crTileGridSpacing) {
                  HStack(spacing: crTileGridSpacing) {
                    activeTile(at: 0)
                    activeTile(at: 1)
                  }
                  HStack(spacing: crTileGridSpacing) {
                    activeTile(at: 2)
                    activeTile(at: 3)
                  }
                }
                .zIndex(1)
              }
              .padding(.bottom, Theme.Spacing.xl)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)

            // Error flash overlay
            if showingErrorFlash {
              Color.red.opacity(0.3)
                .ignoresSafeArea()
                .transition(.opacity)
            }

            // Streak animation overlay
            if showStreakAnimation {
              StreakAnimationView(streakCount: streakDisplayCount)
                .transition(.asymmetric(
                  insertion: .scale.combined(with: .opacity),
                  removal: .opacity
                ))
                .zIndex(1000)
            }

            // Level intro pop-in overlay
            if showLevelIntro {
              LevelIntroView(
                levelRun: levelRun,
                onDismiss: {
                  dismissLevelIntroAndStart()
                }
              )
              .zIndex(2000)
              .transition(.opacity)
            }
          }
        }
      }
      #if !os(macOS)
      .navigationBarHidden(true)
      #endif
      .onAppear {
        startLevel()
      }
      .onDisappear {
        endGameSession()
      }
      #if canImport(UIKit)
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
        pauseTimer()
      }
      .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
        resumeTimer()
      }
      #elseif os(macOS)
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
        pauseTimer()
      }
      .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
        resumeTimer()
      }
      #endif
      .onChange(of: showLevelIntro) { _, isShowing in
        // Wipe in-flight particles AND any lingering streak toast between
        // levels so they don't leak across level transitions (new level OR
        // retry).
        if isShowing {
          clearAllSparkBursts()
          showStreakAnimation = false
          streakDisplayCount = 0
        }
      }
      .onChange(of: levelRun.lastBonusEarned) { _, newValue in
        if newValue > 0 {
          streakDisplayCount = levelRun.currentStreak
          showStreakAnimation = true
          LogService.shared.log("streak_bonus_earned", [
            "level": levelRun.currentLevel,
            "gameType": levelRun.gameType.rawValue,
            "streakCount": levelRun.currentStreak,
            "bonusValue": newValue,
          ])
          // Visual celebration: 4 simultaneous bursts at the 4 tile centers.
          fireStreakCelebration()
          // Reset the trigger after a short delay
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard isGameSessionActive else { return }
            levelRun.lastBonusEarned = 0
          }
          // Hide animation after fade out completes (1.8 seconds total: 1.5s
          // visible + 0.3s fade)
          DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            guard isGameSessionActive else { return }
            showStreakAnimation = false
          }
        }
      }
      .onChange(of: isLevelComplete) { _, isComplete in
        if isComplete { AdsService.shared.recordLevelPlayed() }
      }
      .onChange(of: isLevelFailed) { _, isFailed in
        if isFailed { AdsService.shared.recordLevelPlayed() }
      }
    }
    #if !os(macOS)
    .navigationViewStyle(StackNavigationViewStyle())
    #endif
  }

  // MARK: - Tile rendering + tap burst (purely visual)

  private var targetProgress: Double {
    let target = max(1, levelRun.getRequiredScore())
    return min(1.0, max(0.0, Double(levelRun.currentScore) / Double(target)))
  }

  @ViewBuilder
  private func activeTile(at index: Int) -> some View {
    let trigger: (CGPoint) -> Void = { tapLocation in
      pendingBurstOrigin = tapPositionInCanvas(
        forTile: index,
        tapLocation: tapLocation
      )
      lastTappedIndex = index
      handleTileTap(index)
    }
    Group {
      if levelRun.gameType == .colorOnly {
        ColorTile(
          color: tiles.count > index ? tiles[index] : .gray,
          action: trigger
        )
      } else {
        ColorAndTextTile(
          tile: tilesWithText.count > index ? tilesWithText[index] : Tile(
            backgroundColor: .gray,
            textLabel: "gray"
          ),
          action: trigger
        )
      }
    }
    .onChange(of: levelRun.levelCorrectAnswers) { _, _ in
      // Fired after handleTileTap incremented levelCorrectAnswers (correct
      // tap path). Use the tap location we captured at gesture time.
      guard let idx = lastTappedIndex, idx == index,
            let origin = pendingBurstOrigin else { return }
      let count = particleCountForCurrentStreak()
      fireSparkBurst(at: origin, color: currentTileColor(at: idx), particleCount: count)
      pendingBurstOrigin = nil
    }
  }

  private func fireSparkBurst(at origin: CGPoint, color: Color, particleCount: Int) {
    sparkCounter += 1
    let spec = CRSparkBurstSpec(
      id: sparkCounter,
      origin: origin,
      baseColor: color,
      particleCount: particleCount
    )
    sparkBursts.append(spec)
    // Keep the queue bounded — older specs are already fired and pruned by id.
    if sparkBursts.count > 16 {
      sparkBursts.removeFirst(sparkBursts.count - 16)
    }
  }

  /// 1st correct tap = 2, 2nd = 4, ..., capped at 300 (streak ≥ 150).
  /// Wrong taps reset `levelRun.currentStreak` to 0 in the model so the
  /// next correct tap restarts at 2.
  private func particleCountForCurrentStreak() -> Int {
    let streak = max(1, levelRun.currentStreak)
    return min(300, streak * 2)
  }

  /// Wipe all in-flight particles, e.g. between levels. Bumps the clear
  /// token observed by `CRSparkEmitterView`, which removes its CAEmitterLayer
  /// sublayers, and empties the pending bursts queue.
  private func clearAllSparkBursts() {
    sparkBursts.removeAll()
    sparkClearToken &+= 1
  }

  /// Fire four simultaneous bursts (one centered on each of the 4 tiles)
  /// when a streak bonus is awarded. Each uses one of the four tile colors
  /// for visual variety. Triggered by `.onChange(of: levelRun.lastBonusEarned)`.
  private func fireStreakCelebration() {
    let palette: [Color] = [.red, .blue, .green, .yellow]
    let count = particleCountForCurrentStreak()
    for idx in 0..<4 {
      fireSparkBurst(
        at: burstOrigin(forTile: idx),
        color: palette[idx],
        particleCount: count
      )
    }
  }

  /// Convert a tap location in tile-local coords to the burst canvas's
  /// coordinate space (the 420×420 frame containing the tile grid).
  private func tapPositionInCanvas(
    forTile index: Int,
    tapLocation: CGPoint
  ) -> CGPoint {
    let center = burstOrigin(forTile: index)
    let tileTopLeft = CGPoint(
      x: center.x - crTileSide / 2,
      y: center.y - crTileSide / 2
    )
    return CGPoint(
      x: tileTopLeft.x + tapLocation.x,
      y: tileTopLeft.y + tapLocation.y
    )
  }

  private func burstOrigin(forTile index: Int) -> CGPoint {
    let col = CGFloat(index % 2)
    let row = CGFloat(index / 2)
    return CGPoint(
      x: crBurstOriginEdgeOffset
        + col * (crTileSide + crTileGridSpacing)
        + crTileSide / 2,
      y: crBurstOriginEdgeOffset
        + row * (crTileSide + crTileGridSpacing)
        + crTileSide / 2
    )
  }

  private func currentTileColor(at index: Int) -> Color {
    if levelRun.gameType == .colorOnly {
      return tiles.count > index ? tiles[index] : .gray
    } else {
      return tilesWithText.count > index ? tilesWithText[index].backgroundColor : .gray
    }
  }

  // MARK: - Game logic

  private func handleTileTap(_ index: Int) {
    guard isGameActive, isGameSessionActive, !isLevelComplete,
          !isLevelFailed else { return }

    // Block additional taps in this round; startNewRound() will re-enable.
    isGameActive = false

    // End round timer immediately
    endRoundTimer()

    let isCorrect: Bool
    let tappedBackgroundColor: Color

    if levelRun.gameType == .colorOnly {
      // Color Only mode: correctness depends ONLY on background color
      guard index < tiles.count else { return }
      tappedBackgroundColor = tiles[index]
      isCorrect = tappedBackgroundColor != announcedColor
    } else {
      // Color + Text mode: correctness depends on BOTH background color AND
      // text label
      guard index < tilesWithText.count else { return }
      let tappedTile = tilesWithText[index]
      tappedBackgroundColor = tappedTile.backgroundColor
      let announcedColorName = colorName(for: announcedColor)

      // Wrong if background matches OR text label matches
      // Correct only if BOTH background ≠ announced AND text ≠ announced
      let backgroundMatches = tappedTile.backgroundColor == announcedColor
      let textMatches = tappedTile.textLabel.lowercased() == announcedColorName
        .lowercased()
      isCorrect = !backgroundMatches && !textMatches
    }

    // Update tracking: track consecutive correct taps per position
    if isCorrect {
      // This position was correct - increment counter
      consecutiveCorrectByPosition[index] =
        (consecutiveCorrectByPosition[index] ?? 0) + 1
    } else {
      // This position was incorrect - reset counter for this position
      consecutiveCorrectByPosition[index] = 0
    }

    print(
      "Tile tapped: index \(index), \(colorName(for: tappedBackgroundColor)), Announced: \(colorName(for: announcedColor)), Correct: \(isCorrect), Consecutive correct for this position: \(consecutiveCorrectByPosition[index] ?? 0)"
    )

    if isCorrect {
      // Correct tap
      levelRun.addCorrectAnswer()
      print("Score after correct: \(levelRun.currentScore)")
      hapticsService.lightImpact()
    } else {
      // Incorrect tap
      levelRun.addWrongAnswer()
      print("Score after incorrect: \(levelRun.currentScore)")
      hapticsService.heavyImpact()
      showErrorFlash()
    }

    // Check if level is complete or failed
    checkLevelStatus()

    // Wait 300ms then start next round
    pendingNextRound?.cancel()
    let item = DispatchWorkItem {
      if isGameSessionActive, !isLevelComplete, !isLevelFailed {
        startNewRound()
      }
    }
    pendingNextRound = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
  }

  private func checkLevelStatus() {
    guard levelRun.currentLevelConfig != nil else { return }

    // Only check for failure conditions during gameplay
    // Level completion is checked when timer runs out

    // Check if no lives remaining (game over)
    if levelRun.isGameOver {
      isLevelFailed = true
      failedReason = .maxMistakes // Reuse this reason for "out of lives"
      return
    }
  }

  private func startLevel() {
    guard levelRun.currentLevelConfig != nil else { return }

    // Show level intro pop-in first
    showLevelIntro = true

    // Auto-dismiss after 3 seconds
    pendingIntroDismiss?.cancel()
    let item = DispatchWorkItem {
      if showLevelIntro {
        dismissLevelIntroAndStart()
      }
    }
    pendingIntroDismiss = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: item)
  }

  private func dismissLevelIntroAndStart() {
    showLevelIntro = false

    guard let levelConfig = levelRun.currentLevelConfig else { return }

    LogService.shared.log("level_started", [
      "level": levelRun.currentLevel,
      "gameType": levelRun.gameType.rawValue,
      "mistakeTolerance": levelRun.mistakeTolerance.rawValue,
      "requiredScore": levelRun.getRequiredScore(),
      "timePerResponse": levelConfig.timePerResponse as Any,
      "durationSec": levelConfig.durationSeconds,
    ])

    isGameSessionActive = true
    isGameActive = false

    // Reset level-specific stats
    levelRun.startLevel()

    // Reset timers
    timeRemaining = Double(levelConfig.durationSeconds)
    roundTimeRemaining = 0

    // Reset color tracking
    recentAnnouncedColors = []

    // Reset position tracking for new level
    consecutiveCorrectByPosition = [:]

    // Start global timer
    gameTimer = Timer
      .scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        guard isGameSessionActive else { return }
        if timeRemaining > 0 {
          timeRemaining -= 0.1
        } else {
          handleTimeUp()
        }
      }

    // Start first round
    startNewRound()
  }

  private func startNewLevel() {
    guard isLevelFailed || isLevelComplete else { return }
    endGameSession() // Stop previous timer
    isLevelComplete = false
    isLevelFailed = false
    levelRun.resetLevelStats()
    startLevel()
  }

  private func startNewRound() {
    isGameActive = false

    // Note: We DON'T reset consecutiveCorrectByPosition here because we want to
    // track
    // across rounds to prevent the same position from being correct 4+ times in
    // a row
    // The tracking will be reset when a position becomes incorrect or at level
    // start

    // Store previous tiles for comparison
    if levelRun.gameType == .colorOnly {
      previousTiles = tiles
    } else {
      previousTilesWithText = tilesWithText
    }

    // Select random announced color with repeat prevention
    announcedColor = selectAnnouncedColor()

    // Update recent colors tracking
    updateRecentColors(announcedColor)

    // Speak the announced color
    let colorNameString = colorName(for: announcedColor)
    speechService.speak(colorNameString)

    // Build valid grid based on game type
    if levelRun.gameType == .colorOnly {
      tiles = buildValidGrid()
    } else {
      tilesWithText = buildValidGridWithText()
    }

    // Enable game after a brief delay
    pendingActivation?.cancel()
    let item = DispatchWorkItem {
      isGameActive = true

      // Start round timer if level has time limit
      if let levelConfig = levelRun.currentLevelConfig,
         levelConfig.hasTimeLimit
      {
        startRoundTimer(timeLimit: levelConfig.timePerResponse ?? 1.5)
      }
    }
    pendingActivation = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
  }

  // Refresh board only (for non-punitive refresh levels 9-10)
  // Keeps the same announced color, re-speaks it for audio reinforcement, and
  // reshuffles the tiles
  private func refreshBoardOnly() {
    isGameActive = false

    // Note: We DON'T reset consecutiveCorrectByPosition here because tiles
    // change position
    // but we still want to track to prevent the same position from being
    // correct 4+ times

    // Store previous tiles for comparison
    if levelRun.gameType == .colorOnly {
      previousTiles = tiles
    } else {
      previousTilesWithText = tilesWithText
    }

    // Keep the same announced color but re-speak it so the audio cue stays in
    // sync with the visual board (BUG-008).
    speechService.speak(colorName(for: announcedColor))

    // Build valid grid based on game type (with the same announced color)
    if levelRun.gameType == .colorOnly {
      tiles = buildValidGrid()
    } else {
      tilesWithText = buildValidGridWithText()
    }

    // Enable game after a brief delay
    pendingActivation?.cancel()
    let item = DispatchWorkItem {
      isGameActive = true

      // Restart round timer for non-punitive refresh
      if let levelConfig = levelRun.currentLevelConfig,
         levelConfig.hasTimeLimit
      {
        startRoundTimer(timeLimit: levelConfig.timePerResponse ?? 1.5)
      }
    }
    pendingActivation = item
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: item)
  }

  private func buildValidGrid() -> [Color] {
    var attempts = 0
    let maxAttempts = 20

    while attempts < maxAttempts {
      var grid: [Color] = []
      let nonAnnouncedColors = colorPalette.filter { $0 != announcedColor }

      // CRITICAL: Guarantee at least 1 incorrect (announced color) and 1 correct (different color)
      // Add the announced color at least once (incorrect tile)
      grid.append(announcedColor)

      // Add at least one different color (correct tile)
      guard let differentColor = nonAnnouncedColors.randomElement() else {
        attempts += 1
        continue
      }
      grid.append(differentColor)

      // Fill remaining 2 slots: ensure we maintain at least 1 correct and 1
      // incorrect
      // Strategy: Add 1 more announced color and 1 more different color
      if grid.count < 4 {
        grid.append(announcedColor) // Add another incorrect tile
      }
      if grid.count < 4 {
        // Add another correct tile (different from announced)
        if let anotherDifferentColor = nonAnnouncedColors.randomElement() {
          grid.append(anotherDifferentColor)
        } else {
          grid.append(differentColor) // Fallback to the same different color
        }
      }

      // Shuffle the grid
      var shuffledGrid = grid.shuffled()

      // Ensure positions that have been correct 4+ times are NOT correct in
      // this grid
      // BUT always maintain at least one correct tile
      var positionsToMakeIncorrect: [Int] = []
      for (position, consecutiveCount) in consecutiveCorrectByPosition {
        guard position < shuffledGrid.count else { continue }
        if consecutiveCount >= 4 {
          positionsToMakeIncorrect.append(position)
        }
      }

      // If we need to make positions incorrect, do it carefully
      if !positionsToMakeIncorrect.isEmpty {
        // Count how many correct tiles we currently have
        let correctTilesCount = shuffledGrid.filter { $0 != announcedColor }
          .count

        // We need at least 1 correct tile, so if making positions incorrect
        // would leave us with 0, skip this grid
        let wouldLeaveCorrectTiles = correctTilesCount -
          positionsToMakeIncorrect.count
        if wouldLeaveCorrectTiles < 1 {
          // This grid would have no correct tiles, try again
          attempts += 1
          continue
        }

        // Make the positions incorrect by setting them to announced color
        for position in positionsToMakeIncorrect {
          shuffledGrid[position] = announcedColor
        }
      }

      // Final verification: ensure we have at least 1 correct and 1 incorrect
      let finalCorrectCount = shuffledGrid.filter { $0 != announcedColor }.count
      let finalIncorrectCount = shuffledGrid.filter { $0 == announcedColor }
        .count

      if finalCorrectCount >= 1, finalIncorrectCount >= 1 {
        // Check if different from previous round
        if shuffledGrid != previousTiles {
          return shuffledGrid
        }
      }

      attempts += 1
    }

    // Fallback: guarantee at least 1 correct and 1 incorrect
    let nonAnnouncedColors = colorPalette.filter { $0 != announcedColor }
    guard let correctColor1 = nonAnnouncedColors.randomElement() else {
      // If no non-announced colors available (shouldn't happen), use a fallback
      return [announcedColor, .red, .blue, .green]
        .filter { $0 != announcedColor || $0 == announcedColor }
    }
    let correctColor2 = nonAnnouncedColors.count > 1 ? nonAnnouncedColors
      .filter { $0 != correctColor1 }
      .randomElement() ?? correctColor1 : correctColor1

    var fallbackGrid = [
      announcedColor,
      announcedColor,
      correctColor1,
      correctColor2,
    ]

    // Count correct tiles before modifications
    let correctTilesCount = fallbackGrid.filter { $0 != announcedColor }.count
    var positionsToMakeIncorrect: [Int] = []
    for (position, consecutiveCount) in consecutiveCorrectByPosition {
      guard position < fallbackGrid.count else { continue }
      if consecutiveCount >= 4 {
        positionsToMakeIncorrect.append(position)
      }
    }

    // Only make positions incorrect if we'll still have at least 1 correct tile
    if correctTilesCount - positionsToMakeIncorrect.count >= 1 {
      for position in positionsToMakeIncorrect {
        fallbackGrid[position] = announcedColor
      }
    }

    // Final verification of fallback
    let finalCorrect = fallbackGrid.filter { $0 != announcedColor }.count
    let finalIncorrect = fallbackGrid.filter { $0 == announcedColor }.count

    if finalCorrect >= 1, finalIncorrect >= 1 {
      return fallbackGrid.shuffled()
    } else {
      // Last resort: force 2 correct and 2 incorrect
      return [announcedColor, announcedColor, correctColor1, correctColor2]
        .shuffled()
    }
  }

  private func buildValidGridWithText() -> [Tile] {
    var attempts = 0
    let maxAttempts = 20 // Increased attempts for better reliability
    let announcedColorName = colorName(for: announcedColor)
    let colorNames = colorPalette.map { colorName(for: $0) }

    while attempts < maxAttempts {
      var grid: [Tile] = []

      // Requirement 1: At least one tile with background = announced color
      // (wrong by background)
      // This tile can have any text label
      let wrongByBackgroundLabel = colorNames.randomElement() ?? "red"
      grid.append(Tile(
        backgroundColor: announcedColor,
        textLabel: wrongByBackgroundLabel
      ))

      // Requirement 2: At least one tile with text label = announced color name
      // (wrong by text)
      // This tile must have background ≠ announced color
      let nonAnnouncedColors = colorPalette.filter { $0 != announcedColor }
      guard let wrongByTextColor = nonAnnouncedColors.randomElement() else {
        attempts += 1
        continue
      }
      grid.append(Tile(
        backgroundColor: wrongByTextColor,
        textLabel: announcedColorName
      ))

      // Requirement 3: At least one tile that is correct (both background ≠
      // announced AND text ≠ announced)
      // CRITICAL: This must always exist
      guard let correctColor = nonAnnouncedColors.randomElement() else {
        attempts += 1
        continue
      }
      let correctColorName = colorName(for: correctColor)
      let nonMatchingLabels = colorNames
        .filter {
          $0.lowercased() != announcedColorName.lowercased() && $0
            .lowercased() != correctColorName.lowercased()
        }
      guard let correctLabel = nonMatchingLabels.randomElement() ?? colorNames
        .first(where: { $0.lowercased() != announcedColorName.lowercased() })
      else {
        attempts += 1
        continue
      }
      grid.append(Tile(backgroundColor: correctColor, textLabel: correctLabel))

      // Fill remaining slot (4th tile) - ensure we maintain at least 1 correct
      // tile
      // We already have: 1 wrong by background, 1 wrong by text, 1 correct
      // For the 4th tile, add another incorrect tile (wrong by background) to
      // maintain balance
      if grid.count < 4 {
        let fourthTileLabel = colorNames.randomElement() ?? "blue"
        grid.append(Tile(
          backgroundColor: announcedColor,
          textLabel: fourthTileLabel
        ))
      }

      // Validate that we have all three required tile types
      let hasWrongByBackground = grid
        .contains { $0.backgroundColor == announcedColor }
      let hasWrongByText = grid
        .contains {
          $0.textLabel.lowercased() == announcedColorName.lowercased() && $0
            .backgroundColor != announcedColor
        }
      let correctTiles = grid.filter { tile in
        tile.backgroundColor != announcedColor && tile.textLabel
          .lowercased() != announcedColorName.lowercased()
      }
      let hasCorrectTile = !correctTiles.isEmpty

      // CRITICAL: Must have at least one correct tile and at least one incorrect tile
      guard hasWrongByBackground, hasWrongByText, hasCorrectTile else {
        attempts += 1
        continue
      }

      // Final check: ensure we have at least 1 correct and at least 1 incorrect
      let incorrectTiles = grid.filter { tile in
        tile.backgroundColor == announcedColor || tile.textLabel
          .lowercased() == announcedColorName.lowercased()
      }
      guard incorrectTiles.count >= 1, correctTiles.count >= 1 else {
        attempts += 1
        continue
      }

      // Shuffle the grid
      var shuffledGrid = grid.shuffled()

      // Ensure positions that have been correct 4+ times are NOT correct in
      // this grid
      // BUT always maintain at least one correct tile
      var positionsToMakeIncorrect: [Int] = []
      for (position, consecutiveCount) in consecutiveCorrectByPosition {
        guard position < shuffledGrid.count else { continue }
        if consecutiveCount >= 4 {
          let tile = shuffledGrid[position]
          // Check if this position is currently correct
          let backgroundMatches = tile.backgroundColor == announcedColor
          let textMatches = tile.textLabel.lowercased() == announcedColorName
            .lowercased()
          if !backgroundMatches, !textMatches {
            // This position is correct and needs to be made incorrect
            positionsToMakeIncorrect.append(position)
          }
        }
      }

      // If we need to make positions incorrect, do it carefully
      if !positionsToMakeIncorrect.isEmpty {
        // Count how many correct tiles we currently have
        let correctTilesCount = shuffledGrid.filter { tile in
          tile.backgroundColor != announcedColor && tile.textLabel
            .lowercased() != announcedColorName.lowercased()
        }.count

        // We need at least 1 correct tile, so if making positions incorrect
        // would leave us with 0, skip this grid
        let wouldLeaveCorrectTiles = correctTilesCount -
          positionsToMakeIncorrect.count
        if wouldLeaveCorrectTiles < 1 {
          // This grid would have no correct tiles, try again
          attempts += 1
          continue
        }

        // Make the positions incorrect (either by background or text matching
        // announced)
        for position in positionsToMakeIncorrect {
          // Make it wrong by setting background to announced color (simpler)
          shuffledGrid[position] = Tile(
            backgroundColor: announcedColor,
            textLabel: colorNames.randomElement() ?? "blue"
          )
        }
      }

      // CRITICAL: Final verification - must have at least one correct tile AND one incorrect tile
      let finalCorrectTiles = shuffledGrid.filter { tile in
        tile.backgroundColor != announcedColor && tile.textLabel
          .lowercased() != announcedColorName.lowercased()
      }
      let finalIncorrectTiles = shuffledGrid.filter { tile in
        tile.backgroundColor == announcedColor || tile.textLabel
          .lowercased() == announcedColorName.lowercased()
      }

      guard finalCorrectTiles.count >= 1, finalIncorrectTiles.count >= 1 else {
        // Must have at least 1 correct and 1 incorrect tile, try again
        attempts += 1
        continue
      }

      // Check if different from previous round
      if shuffledGrid != previousTilesWithText {
        return shuffledGrid
      }

      attempts += 1
    }

    // Fallback: ensure all three types exist and ALWAYS have at least one correct tile
    var fallbackGrid: [Tile] = []
    // Wrong by background
    fallbackGrid.append(Tile(
      backgroundColor: announcedColor,
      textLabel: "blue"
    ))
    // Wrong by text
    let fallbackWrongByTextColor = colorPalette
      .first { $0 != announcedColor } ?? .blue
    fallbackGrid.append(Tile(
      backgroundColor: fallbackWrongByTextColor,
      textLabel: announcedColorName
    ))
    // CRITICAL: At least one correct tile (background ≠ announced AND text ≠ announced)
    let fallbackCorrectColor = colorPalette
      .first { $0 != announcedColor && $0 != fallbackWrongByTextColor } ??
      .green
    let fallbackCorrectColorName = colorName(for: fallbackCorrectColor)
    // Ensure the label is different from announced color name
    let fallbackCorrectLabel = colorNames
      .first {
        $0.lowercased() != announcedColorName.lowercased() && $0
          .lowercased() != fallbackCorrectColorName.lowercased()
      } ?? "red"
    fallbackGrid.append(Tile(
      backgroundColor: fallbackCorrectColor,
      textLabel: fallbackCorrectLabel
    ))
    // Fill 4th slot - make it incorrect to be safe
    fallbackGrid.append(Tile(
      backgroundColor: announcedColor,
      textLabel: colorNames.randomElement() ?? "yellow"
    ))

    // Ensure positions with 4+ consecutive correct are forced to be incorrect
    // BUT always maintain at least one correct tile
    var shuffledFallback = fallbackGrid.shuffled()

    // Count correct tiles before modifications
    var correctTilesCount = shuffledFallback.filter { tile in
      tile.backgroundColor != announcedColor && tile.textLabel
        .lowercased() != announcedColorName.lowercased()
    }.count

    // CRITICAL: If we have no correct tiles in fallback, force at least one
    if correctTilesCount == 0 {
      // Find a position and make it correct
      if let firstPosition = shuffledFallback.indices.first {
        let safeColor = colorPalette.first { $0 != announcedColor } ?? .blue
        let safeColorName = colorName(for: safeColor)
        let safeLabel = colorNames
          .first {
            $0.lowercased() != announcedColorName.lowercased() && $0
              .lowercased() != safeColorName.lowercased()
          } ?? "red"
        shuffledFallback[firstPosition] = Tile(
          backgroundColor: safeColor,
          textLabel: safeLabel
        )
        correctTilesCount = 1
      }
    }

    var positionsToMakeIncorrect: [Int] = []
    for (position, consecutiveCount) in consecutiveCorrectByPosition {
      guard position < shuffledFallback.count else { continue }
      if consecutiveCount >= 4 {
        let tile = shuffledFallback[position]
        // Check if this position is currently correct
        let backgroundMatches = tile.backgroundColor == announcedColor
        let textMatches = tile.textLabel.lowercased() == announcedColorName
          .lowercased()
        if !backgroundMatches, !textMatches {
          // This position is correct and needs to be made incorrect
          positionsToMakeIncorrect.append(position)
        }
      }
    }

    // Only make positions incorrect if we'll still have at least 1 correct tile
    if correctTilesCount - positionsToMakeIncorrect.count >= 1 {
      for position in positionsToMakeIncorrect {
        // Make it wrong by setting background to announced color
        shuffledFallback[position] = Tile(
          backgroundColor: announcedColor,
          textLabel: colorNames.randomElement() ?? "blue"
        )
      }
    }

    // FINAL CRITICAL CHECK: Verify we have at least one correct tile
    let finalCorrectCount = shuffledFallback.filter { tile in
      tile.backgroundColor != announcedColor && tile.textLabel
        .lowercased() != announcedColorName.lowercased()
    }.count

    // If somehow we still have no correct tiles, force one
    if finalCorrectCount == 0 {
      // Find first position and make it correct
      if let firstPosition = shuffledFallback.indices.first {
        let safeColor = colorPalette.first { $0 != announcedColor } ?? .blue
        let safeColorName = colorName(for: safeColor)
        let safeLabel = colorNames
          .first {
            $0.lowercased() != announcedColorName.lowercased() && $0
              .lowercased() != safeColorName.lowercased()
          } ?? "red"
        shuffledFallback[firstPosition] = Tile(
          backgroundColor: safeColor,
          textLabel: safeLabel
        )
      }
    }

    return shuffledFallback
  }

  private func startRoundTimer(timeLimit: Double) {
    endRoundTimer()
    roundTimeRemaining = timeLimit
    isRoundTimerActive = true

    roundTimer = Timer
      .scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        guard isRoundTimerActive else { return }
        roundTimeRemaining -= 0.1

        if roundTimeRemaining <= 0 {
          handleRoundTimeout()
        }
      }
  }

  private func endRoundTimer() {
    roundTimer?.invalidate()
    roundTimer = nil
    isRoundTimerActive = false
  }

  private func handleRoundTimeout() {
    // Only check if game session is active and level is not complete/failed
    // Don't check isGameActive here because it might be false when timer
    // expires
    guard isGameSessionActive, !isLevelComplete, !isLevelFailed else {
      print(
        "Timeout blocked: isGameSessionActive=\(isGameSessionActive), isLevelComplete=\(isLevelComplete), isLevelFailed=\(isLevelFailed)"
      )
      return
    }

    // Check if this is a non-punitive refresh level (9-10)
    if let levelConfig = levelRun.currentLevelConfig,
       levelConfig.isNonPunitiveRefresh
    {
      // Non-punitive refresh: just refresh the board, keep same announced
      // color, no penalty
      endRoundTimer()
      refreshBoardOnly()
    } else {
      // Regular timeout: apply penalty
      print("Applying timeout penalty: -5 points")
      levelRun.addTimeout()
      print("Score after timeout: \(levelRun.currentScore)")
      hapticsService.heavyImpact()
      showErrorFlash()

      endRoundTimer()
      checkLevelStatus()

      pendingNextRound?.cancel()
      let item = DispatchWorkItem {
        if isGameSessionActive, !isLevelComplete, !isLevelFailed {
          startNewRound()
        }
      }
      pendingNextRound = item
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
    }
  }

  private func handleTimeUp() {
    endGameSession()

    // Check if level was completed successfully
    guard levelRun.currentLevelConfig != nil else {
      isLevelFailed = true
      failedReason = .insufficientScore
      return
    }

    // Check if score meets requirement (streak bonuses are already included in
    // currentScore)
    let requiredScore = levelRun.getRequiredScore()
    let currentLevel = levelRun.currentLevel
    if levelRun.getCurrentLevelScore() >= requiredScore {
      isLevelComplete = true
      LogService.shared.log("level_completed", [
        "level": currentLevel,
        "gameType": levelRun.gameType.rawValue,
        "mistakeTolerance": levelRun.mistakeTolerance.rawValue,
        "score": levelRun.getCurrentLevelScore(),
        "requiredScore": requiredScore,
        "hits": levelRun.levelBasePoints,
        "misses": levelRun.levelWrongTaps,
        "streakBonuses": levelRun.levelStreakBonuses,
        "livesRemaining": levelRun.remainingLives,
      ])
    } else {
      // Level failed due to insufficient score - lose 1 life
      levelRun.loseLife()

      isLevelFailed = true
      failedReason = .insufficientScore

      // Check if no lives remaining (game over)
      if levelRun.isGameOver {
        failedReason = .maxMistakes // Reuse this reason for "out of lives"
      }
      LogService.shared.log("level_failed", [
        "level": currentLevel,
        "gameType": levelRun.gameType.rawValue,
        "mistakeTolerance": levelRun.mistakeTolerance.rawValue,
        "score": levelRun.getCurrentLevelScore(),
        "requiredScore": requiredScore,
        "reason": failedReason == .maxMistakes ? "maxMistakes" : "insufficientScore",
        "livesRemaining": levelRun.remainingLives,
      ])
      if levelRun.isGameOver {
        LogService.shared.log("run_game_over", [
          "level": currentLevel,
          "score": levelRun.globalScore,
          "gameType": levelRun.gameType.rawValue,
          "mistakeTolerance": levelRun.mistakeTolerance.rawValue,
        ])
      }
    }
  }

  private func showErrorFlash() {
    withAnimation(.easeInOut(duration: 0.1)) {
      showingErrorFlash = true
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
      guard isGameSessionActive else { return }
      withAnimation(.easeInOut(duration: 0.1)) {
        showingErrorFlash = false
      }
    }
  }

  private func colorName(for color: Color) -> String {
    if color == .red { return "red" }
    if color == .blue { return "blue" }
    if color == .green { return "green" }
    if color == .yellow { return "yellow" }
    return "unknown"
  }

  private func selectAnnouncedColor() -> Color {
    guard recentAnnouncedColors.count >= 2 else {
      return colorPalette.randomElement() ?? .red
    }

    let lastTwoColors = Array(recentAnnouncedColors.suffix(2))
    if lastTwoColors[0] == lastTwoColors[1] {
      let excludedColor = lastTwoColors[0]
      let availableColors = colorPalette.filter { $0 != excludedColor }
      return availableColors.randomElement() ?? .red
    }

    return colorPalette.randomElement() ?? .red
  }

  private func updateRecentColors(_ color: Color) {
    recentAnnouncedColors.append(color)
    if recentAnnouncedColors.count > 2 {
      recentAnnouncedColors.removeFirst()
    }
  }

  private func endGameSession() {
    isGameSessionActive = false
    isGameActive = false
    gameTimer?.invalidate()
    gameTimer = nil
    endRoundTimer()

    pendingNextRound?.cancel()
    pendingNextRound = nil
    pendingIntroDismiss?.cancel()
    pendingIntroDismiss = nil
    pendingActivation?.cancel()
    pendingActivation = nil
  }

  private func pauseTimer() {
    guard isGameSessionActive else { return }
    backgroundTime = Date()
    gameTimer?.invalidate()
    gameTimer = nil

    if isRoundTimerActive {
      roundTimer?.invalidate()
      roundTimer = nil
    }
  }

  private func resumeTimer() {
    guard isGameSessionActive, let backgroundTime else { return }

    let elapsedTime = Date().timeIntervalSince(backgroundTime)
    timeRemaining -= elapsedTime

    if timeRemaining <= 0 {
      handleTimeUp()
      return
    }

    // Re-anchor the player by re-speaking the announced color (BUG-012).
    speechService.speak(colorName(for: announcedColor))

    gameTimer = Timer
      .scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
        guard isGameSessionActive else { return }
        if timeRemaining > 0 {
          timeRemaining -= 0.1
        } else {
          handleTimeUp()
        }
      }

    if isRoundTimerActive {
      startRoundTimer(timeLimit: roundTimeRemaining)
    }

    self.backgroundTime = nil
  }
}

// MARK: - Level Intro View

struct LevelIntroView: View {
  @ObservedObject var levelRun: LevelRun
  let onDismiss: () -> Void

  static let autoPlayDuration: TimeInterval = 3.0

  @State private var progress: Double = 1.0

  private var subtitle: LocalizedStringKey {
    if levelRun.currentLevel == 1 || levelRun.currentLevel == 2 {
      return "Level \(levelRun.currentLevel) - Warm up"
    }
    return "Level \(levelRun.currentLevel)"
  }

  private var formattedTime: String {
    guard let duration = levelRun.currentLevelConfig?.durationSeconds else {
      return "—:—"
    }
    return String(format: "%02d:%02d", duration / 60, duration % 60)
  }

  var body: some View {
    ZStack {
      Color.black.opacity(0.6).ignoresSafeArea()

      VStack(spacing: Theme.Spacing.lg) {
        timerLine

        Text(subtitle)
          .font(.crLabel)
          .textCase(.uppercase)
          .foregroundStyle(Theme.Colors.textSecondary)
          .multilineTextAlignment(.center)

        beatHeadline

        HStack(spacing: Theme.Spacing.md) {
          timeCard
          livesCard
        }

        Button {
          onDismiss()
        } label: {
          HStack(spacing: Theme.Spacing.sm) {
            Image("CRPlay")
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 16, height: 16)
            Text("Play")
          }
        }
        .buttonStyle(.crPrimary)
      }
      .padding(Theme.Spacing.lg)
      .frame(maxWidth: 320)
      .background(
        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
          .fill(Theme.Colors.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
          .strokeBorder(Theme.Colors.border, lineWidth: 1)
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onAppear {
      withAnimation(.linear(duration: Self.autoPlayDuration)) {
        progress = 0.0
      }
    }
  }

  private var timerLine: some View {
    GeometryReader { geo in
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(Theme.Gradient.primary)
        .frame(width: geo.size.width * CGFloat(progress), height: 3)
    }
    .frame(height: 3)
    .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
  }

  private var beatHeadline: some View {
    (
      Text("BEAT ").foregroundStyle(Theme.Colors.textPrimary)
        + Text("\(levelRun.getRequiredScore())").foregroundStyle(Theme.Colors.accentSecondary)
    )
    .font(.crDisplay)
    .multilineTextAlignment(.center)
  }

  private var timeCard: some View {
    VStack(spacing: Theme.Spacing.xs) {
      Text("TIME")
        .font(.crLabel)
        .textCase(.uppercase)
        .foregroundStyle(Theme.Colors.textSecondary)
      Text(formattedTime)
        .font(.crTitle)
        .foregroundStyle(Theme.Colors.textPrimary)
    }
    .frame(maxWidth: .infinity)
    .padding(Theme.Spacing.md)
    .background(
      RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        .fill(Theme.Colors.surfaceElevated)
    )
  }

  private var livesCard: some View {
    let total = levelRun.mistakeTolerance.totalLives
    let remaining = levelRun.remainingLives
    return VStack(spacing: Theme.Spacing.xs) {
      Text("LIVES")
        .font(.crLabel)
        .textCase(.uppercase)
        .foregroundStyle(Theme.Colors.textSecondary)
      HStack(spacing: 3) {
        ForEach(0..<total, id: \.self) { index in
          Image(systemName: "heart.fill")
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(
              index < remaining ? Theme.Colors.danger : Theme.Colors.danger.opacity(0.18)
            )
        }
      }
    }
    .frame(maxWidth: .infinity)
    .padding(Theme.Spacing.md)
    .background(
      RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        .fill(Theme.Colors.surfaceElevated)
    )
  }
}

// MARK: - Streak Animation View

struct StreakAnimationView: View {
  let streakCount: Int
  @State private var scale: CGFloat = 0.5
  @State private var opacity: Double = 0.0

  var body: some View {
    VStack {
      Spacer()
        .frame(height: 200) // Position below the level title

      HStack(spacing: 8) {
        Text("🔥")
          .font(.system(size: 32))

        Text("\(streakCount) in a row!")
          .font(.system(size: 24, weight: .bold, design: .rounded))
          .foregroundColor(.white)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
      .background(
        LinearGradient(
          gradient: Gradient(colors: [
            Color.orange.opacity(0.9),
            Color.red.opacity(0.9),
          ]),
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .cornerRadius(20)
      .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
      .scaleEffect(scale)
      .opacity(opacity)
      .onAppear {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
          scale = 1.0
          opacity = 1.0
        }

        // Fade out after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
          withAnimation(.easeOut(duration: 0.3)) {
            opacity = 0.0
            scale = 0.8
          }
        }
      }

      Spacer()
    }
    .allowsHitTesting(false) // Don't block touches
  }
}

// MARK: - Level Result Layout (shared between Complete + Failed)

/// Shared layout for the post-level result screens (Frames 6 + 7). The two
/// views differ only in tone color, icon, headline, subtitle suffix, and
/// primary CTA — everything else is identical.
private struct LevelResultBody<PrimaryButton: View, Icon: View>: View {
  let totalScore: Int
  let remainingLives: Int
  let totalLives: Int
  let icon: Icon
  let headline: LocalizedStringKey
  let headlineColor: Color
  let subtitle: LocalizedStringKey
  let dividerColor: Color
  let levelScore: Int
  let requiredScore: Int
  let hitsPoints: Int
  let missesPoints: Int
  let streakBonus: Int
  let primaryButton: PrimaryButton
  let onBackToHome: () -> Void

  var body: some View {
    ZStack {
      Theme.Colors.background.ignoresSafeArea()

      VStack(spacing: Theme.Spacing.lg) {
        // Top row: TOTAL SCORE on left, hearts pill on right
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 2) {
            Text("Total Score")
              .font(.crLabel)
              .textCase(.uppercase)
              .foregroundStyle(Theme.Colors.textSecondary)
            Text("\(totalScore)")
              .font(.crTitle)
              .foregroundStyle(Theme.Colors.textPrimary)
          }
          Spacer()
          CRHeartsPill(remaining: remainingLives, total: totalLives)
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.lg)

        Spacer(minLength: Theme.Spacing.md)

        // Centered icon + headline + subtitle
        VStack(spacing: Theme.Spacing.sm) {
          icon
          Text(headline)
            .font(.crDisplay)
            .textCase(.uppercase)
            .foregroundStyle(headlineColor)
            .multilineTextAlignment(.center)
          Text(subtitle)
            .font(.crLabel)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textSecondary)
        }

        // Tone-coloured divider stuck to the YOUR SCORE card (no gap)
        VStack(spacing: 0) {
          Rectangle()
            .fill(dividerColor)
            .frame(height: 2)
            .padding(.horizontal, Theme.Spacing.xxxl)

          VStack(spacing: Theme.Spacing.xs) {
            Text("Your Score")
              .font(.crLabel)
              .textCase(.uppercase)
              .foregroundStyle(Theme.Colors.textSecondary)
            Text("\(levelScore)")
              .font(.crScoreHero)
              .foregroundStyle(Theme.Colors.textPrimary)
            Text("Of \(requiredScore)")
              .font(.crBody)
              .textCase(.uppercase)
              .foregroundStyle(Theme.Colors.textSecondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, Theme.Spacing.lg)
          .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
              .fill(Theme.Colors.surface)
          )
          .padding(.horizontal, Theme.Spacing.xl)
        }

        // Stats trio
        HStack(spacing: Theme.Spacing.md) {
          CRStatBadge(
            label: "Hits",
            value: hitsPoints > 0 ? "+\(hitsPoints)" : "0",
            tone: .success
          )
          CRStatBadge(
            label: "Misses",
            value: missesPoints == 0 ? "0" : "\(missesPoints)",
            tone: .warning
          )
          CRStatBadge(
            label: "Streak",
            value: streakBonus > 0 ? "+\(streakBonus)" : "0",
            tone: .info
          )
        }
        .padding(.horizontal, Theme.Spacing.xl)

        Spacer(minLength: Theme.Spacing.md)

        primaryButton
          .padding(.horizontal, Theme.Spacing.xl)

        Button {
          SoundService.shared.play(.secondary)
          LogService.shared.log("run_abandoned", [
            "totalScore": totalScore,
            "reason": "level_result_home",
          ])
          onBackToHome()
        } label: {
          Text("Home")
            .font(.crButtonLabel)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textPrimary)
        }
        .buttonStyle(.plain)
        .padding(.bottom, Theme.Spacing.lg)
      }
    }
    .preferredColorScheme(.dark)
  }
}

// MARK: - Level Complete View

struct LevelCompleteView: View {
  @ObservedObject var levelRun: LevelRun
  let onNextLevel: () -> Void
  let onBackToHome: () -> Void

  private var finalLevelScore: Int {
    levelRun.getCurrentLevelScore()
  }

  private var totalScoreWithCurrentLevel: Int {
    levelRun.globalScore + levelRun.levelPositivePoints
  }

  var body: some View {
    LevelResultBody(
      totalScore: totalScoreWithCurrentLevel,
      remainingLives: levelRun.remainingLives,
      totalLives: levelRun.mistakeTolerance.totalLives,
      icon: Image("CRLightning")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 120, height: 120)
        .foregroundStyle(Theme.Colors.success),
      headline: "Amazing",
      headlineColor: Theme.Colors.success,
      subtitle: "Level \(levelRun.currentLevel) - Succeed",
      dividerColor: Theme.Colors.success,
      levelScore: finalLevelScore,
      requiredScore: levelRun.getRequiredScore(),
      hitsPoints: levelRun.levelBasePoints,
      missesPoints: levelRun.levelWrongTaps * -10,
      streakBonus: levelRun.levelStreakBonuses,
      primaryButton: Button(action: onNextLevel) {
        HStack(spacing: Theme.Spacing.sm) {
          if !levelRun.isCompleted {
            Image("CRPlay")
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 18, height: 18)
          }
          Text(levelRun.isCompleted ? "Finish Run" : "Next Level")
        }
      }
      .buttonStyle(.crPrimary),
      onBackToHome: onBackToHome
    )
  }
}

// MARK: - Level Failed View (for insufficient score only)

struct LevelFailedView: View {
  @ObservedObject var levelRun: LevelRun
  let failedReason: LevelFailureReason
  let onRetry: () -> Void
  let onBackToHome: () -> Void

  private var totalScoreWithCurrentLevel: Int {
    levelRun.globalScore + levelRun.levelPositivePoints
  }

  private var finalLevelScore: Int {
    levelRun.getCurrentLevelScore()
  }

  var body: some View {
    LevelResultBody(
      totalScore: totalScoreWithCurrentLevel,
      remainingLives: levelRun.remainingLives,
      totalLives: levelRun.mistakeTolerance.totalLives,
      icon: Image("CRSkull")
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 120, height: 120)
        .foregroundStyle(Theme.Colors.warning),
      headline: "Too slow",
      headlineColor: Theme.Colors.textPrimary,
      subtitle: "Level \(levelRun.currentLevel) - Failed",
      dividerColor: Theme.Colors.warning,
      levelScore: finalLevelScore,
      requiredScore: levelRun.getRequiredScore(),
      hitsPoints: levelRun.levelBasePoints,
      missesPoints: levelRun.levelWrongTaps * -10,
      streakBonus: levelRun.levelStreakBonuses,
      primaryButton: Button(action: onRetry) {
        HStack(spacing: Theme.Spacing.sm) {
          Image("CRRetry")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
          Text("Try Again")
        }
      }
      .buttonStyle(.crPrimary),
      onBackToHome: onBackToHome
    )
  }
}

// MARK: - Final Win View (for completing level 10)

struct FinalWinView: View {
  @ObservedObject var levelRun: LevelRun
  let onPlayHarder: () -> Void
  let onSeeLeaderboard: () -> Void

  // Total score including current level's positive points.
  private var totalScoreWithCurrentLevel: Int {
    levelRun.globalScore + levelRun.levelPositivePoints
  }

  var body: some View {
    ZStack {
      Theme.Colors.background.ignoresSafeArea()

      VStack(spacing: Theme.Spacing.lg) {
        // Top row: hearts pill on the right (lives left = quality of the run).
        HStack {
          Spacer()
          CRHeartsPill(
            remaining: levelRun.remainingLives,
            total: levelRun.mistakeTolerance.totalLives
          )
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.lg)

        Spacer(minLength: Theme.Spacing.md)

        // Crown + headline + subtitle
        VStack(spacing: Theme.Spacing.sm) {
          Image(systemName: "crown.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 120, height: 120)
            .foregroundStyle(Theme.Colors.pro)

          Text("YOU WIN!")
            .font(.crDisplay)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.pro)
            .multilineTextAlignment(.center)

          Text("Run complete · Level \(levelRun.currentLevel)")
            .font(.crLabel)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textSecondary)
        }

        // Gold divider stuck to the Final Score card.
        VStack(spacing: 0) {
          Rectangle()
            .fill(Theme.Colors.pro)
            .frame(height: 2)
            .padding(.horizontal, Theme.Spacing.xxxl)

          VStack(spacing: Theme.Spacing.xs) {
            Text("Final Score")
              .font(.crLabel)
              .textCase(.uppercase)
              .foregroundStyle(Theme.Colors.textSecondary)
            Text(verbatim: "\(totalScoreWithCurrentLevel)")
              .font(.crScoreHero)
              .foregroundStyle(Theme.Colors.textPrimary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, Theme.Spacing.lg)
          .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
              .fill(Theme.Colors.surface)
          )
          .padding(.horizontal, Theme.Spacing.xl)
        }

        Spacer(minLength: Theme.Spacing.md)

        Button {
          SoundService.shared.play(.main)
          LogService.shared.log("final_win_play_harder_pressed", [
            "gameType": levelRun.gameType.rawValue,
            "mistakeTolerance": levelRun.mistakeTolerance.rawValue,
            "finalScore": totalScoreWithCurrentLevel,
          ])
          onPlayHarder()
        } label: {
          Text("Play Harder")
        }
        .buttonStyle(.crPrimary)
        .padding(.horizontal, Theme.Spacing.xl)

        Button {
          SoundService.shared.play(.secondary)
          LogService.shared.log("final_win_see_leaderboard_pressed", [
            "gameType": levelRun.gameType.rawValue,
            "mistakeTolerance": levelRun.mistakeTolerance.rawValue,
            "finalScore": totalScoreWithCurrentLevel,
          ])
          onSeeLeaderboard()
        } label: {
          Text("See Leaderboard")
            .font(.crButtonLabel)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
        .buttonStyle(.plain)
        .padding(.bottom, Theme.Spacing.lg)
      }
    }
    .preferredColorScheme(.dark)
    .onAppear {
      LogService.shared.log("run_completed", [
        "gameType": levelRun.gameType.rawValue,
        "mistakeTolerance": levelRun.mistakeTolerance.rawValue,
        "finalScore": totalScoreWithCurrentLevel,
        "livesRemaining": levelRun.remainingLives,
      ])
    }
  }
}

// MARK: - Game Over View (for run-ending failures)

struct LevelGameOverView: View {
  @ObservedObject var levelRun: LevelRun
  let failedReason: LevelFailureReason
  let onContinueWithExtraLife: () -> Void
  let onBackToHome: () -> Void

  @StateObject private var ads = AdsService.shared
  @StateObject private var store = StoreService.shared

  // Label of the rewarded CTA varies by entitlement.
  private var continueButtonTitle: LocalizedStringKey {
    store.hasRemoveAds ? "❤️ +1 Life (free)" : "❤️ +1 Life — Watch Ad"
  }

  // Disabled when not entitled AND no rewarded ad is loaded yet.
  private var isContinueButtonEnabled: Bool {
    store.hasRemoveAds || ads.rewardedReady
  }

  private var totalScoreWithCurrentLevel: Int {
    levelRun.globalScore + levelRun.levelPositivePoints
  }

  var body: some View {
    ZStack {
      Theme.Colors.background.ignoresSafeArea()
      Theme.Gradient.gameOverWash.ignoresSafeArea()

      VStack(spacing: Theme.Spacing.lg) {
        // Top row: dimmed empty hearts pill on the right
        HStack {
          Spacer()
          CRHeartsPill(
            remaining: 0,
            total: levelRun.mistakeTolerance.totalLives
          )
        }
        .padding(.horizontal, Theme.Spacing.xl)
        .padding(.top, Theme.Spacing.lg)

        Spacer(minLength: Theme.Spacing.md)

        // GAME OVER headline + subtitle + divider
        VStack(spacing: Theme.Spacing.sm) {
          Text("Game Over")
            .font(.crDisplay)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.danger)
          Text("No lives left")
            .font(.crLabel)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textSecondary)
        }

        // Tone-coloured divider stuck to the YOUR TOTAL SCORE card (no gap)
        VStack(spacing: 0) {
          Rectangle()
            .fill(Theme.Colors.danger)
            .frame(height: 2)
            .padding(.horizontal, Theme.Spacing.xxxl)

          VStack(spacing: Theme.Spacing.xs) {
            Text("Your Total Score")
              .font(.crLabel)
              .textCase(.uppercase)
              .foregroundStyle(Theme.Colors.textSecondary)
            Text("\(totalScoreWithCurrentLevel)")
              .font(.crScoreHero)
              .foregroundStyle(Theme.Colors.textPrimary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, Theme.Spacing.lg)
          .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
              .fill(Theme.Colors.surface)
          )
          .padding(.horizontal, Theme.Spacing.xl)
        }

        // DON'T STOP NOW prompt + +1 LIFE rewarded revive card
        if !levelRun.hasUsedRewardedRevive {
          VStack(spacing: Theme.Spacing.xs) {
            Text("Don't stop now")
              .font(.crHeadline)
              .textCase(.uppercase)
              .foregroundStyle(Theme.Colors.textPrimary)
            Text("Watch an ad, get back in")
              .font(.crBody)
              .foregroundStyle(Theme.Colors.textSecondary)
          }
          .padding(.top, Theme.Spacing.sm)

          rewardedReviveCard
            .padding(.horizontal, Theme.Spacing.xl)
        }

        Spacer(minLength: Theme.Spacing.md)

        Button(action: onBackToHome) {
          HStack(spacing: Theme.Spacing.sm) {
            Image("CRRetry")
              .renderingMode(.template)
              .resizable()
              .scaledToFit()
              .frame(width: 18, height: 18)
            Text("Start Over")
          }
        }
        .buttonStyle(.crDanger)
        .padding(.horizontal, Theme.Spacing.xl)

        Button {
          SoundService.shared.play(.secondary)
          LogService.shared.log("run_abandoned", [
            "level": levelRun.currentLevel,
            "score": levelRun.globalScore,
            "reason": "game_over_back_home",
          ])
          onBackToHome()
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
    .preferredColorScheme(.dark)
  }

  /// +1 LIFE rewarded revive card. Heart icon on the left, label column in
  /// the middle, "Watch" pill on the right. Disabled visually when neither
  /// the Remove Ads entitlement is held nor a rewarded ad has loaded yet.
  private var rewardedReviveCard: some View {
    let enabled = isContinueButtonEnabled
    return Button(action: handleContinueTap) {
      HStack(spacing: Theme.Spacing.md) {
        Image(systemName: "heart.fill")
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(Theme.Colors.accentSecondary)

        VStack(alignment: .leading, spacing: 2) {
          Text("+1 Life")
            .font(.crLabel)
            .textCase(.uppercase)
            .foregroundStyle(Theme.Colors.textPrimary)
          Text(store.hasRemoveAds ? "Free" : "Watch 1 Ad")
            .font(.crCaption)
            .foregroundStyle(Theme.Colors.textSecondary)
        }

        Spacer()

        Text("Watch")
          .font(.crLabel)
          .textCase(.uppercase)
          .foregroundStyle(Theme.Colors.textPrimary)
          .padding(.horizontal, Theme.Spacing.md)
          .padding(.vertical, Theme.Spacing.xs + 2)
          .background(
            Capsule(style: .continuous)
              .fill(Theme.Colors.accentSecondary.opacity(0.18))
          )
          .overlay(
            Capsule(style: .continuous)
              .strokeBorder(Theme.Colors.accentSecondary, lineWidth: 1)
          )
      }
      .padding(Theme.Spacing.md)
      .frame(maxWidth: .infinity)
      .background(
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
          .fill(Theme.Colors.surface)
      )
      .overlay(
        RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
          .strokeBorder(Theme.Colors.accentSecondary.opacity(0.4), lineWidth: 1)
      )
      .opacity(enabled ? 1.0 : 0.5)
    }
    .buttonStyle(.plain)
    .disabled(!enabled)
  }

  // Anti-abuse: mark the revive consumed BEFORE presenting the ad, so a
  // user who closes the ad early still loses the one-shot opportunity.
  // Remove Ads holders short-circuit straight to onReward inside
  // showRewardedAdIfReady — no ad shown.
  private func handleContinueTap() {
    SoundService.shared.play(.main)
    LogService.shared.log("revive_attempt", [
      "level": levelRun.currentLevel,
      "hasRemoveAds": store.hasRemoveAds,
      "adReady": ads.rewardedReady,
    ])
    levelRun.markReviveAttempted()
    ads.showRewardedAdIfReady(
      onReward: {
        LogService.shared.log("revive_completed", [
          "level": levelRun.currentLevel,
        ])
        onContinueWithExtraLife()
      },
      onSkip: {
        // Player closed the ad before earning the reward, or no ad/host
        // VC available. The button is already gone (markReviveAttempted
        // flipped the flag). Player can still tap "Start a new game".
        LogService.shared.log("revive_skipped", [
          "level": levelRun.currentLevel,
          "reason": ads.rewardedReady ? "closed_early" : "no_ad",
        ])
      }
    )
  }
}

// MARK: - Color And Text Tile View

struct ColorAndTextTile: View {
  let tile: Tile
  let action: (CGPoint) -> Void

  private func textColor(for backgroundColor: Color) -> Color {
    backgroundColor == .yellow ? .black : .white
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
    return ZStack {
      shape
        .fill(tile.backgroundColor)
        .frame(width: 150, height: 150)
        .overlay(
          shape
            .strokeBorder(
              LinearGradient(
                stops: [
                  .init(color: Color.white.opacity(0.55), location: 0.0),
                  .init(color: Color.white.opacity(0.18), location: 0.45),
                  .init(color: Color.white.opacity(0.0), location: 0.7),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 2
            )
        )

      Text(LocalizedStringKey(tile.textLabel.uppercased()))
        .font(.crHeadline)
        .foregroundStyle(textColor(for: tile.backgroundColor))
    }
    .contentShape(shape)
    .gesture(
      SpatialTapGesture()
        .onEnded { event in
          action(event.location)
        }
    )
  }
}

// MARK: - Color Extension for Hex

extension Color {
  init(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
      (a, r, g, b) = (
        255,
        (int >> 8) * 17,
        (int >> 4 & 0xF) * 17,
        (int & 0xF) * 17
      )
    case 6: // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      (a, r, g, b) = (255, 0, 0, 0)
    }
    self.init(
      .sRGB,
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      opacity: Double(a) / 255
    )
  }
}

#Preview {
  LevelGameView(levelRun: LevelRun())
}
