import Combine
import Foundation
import GameKit
import UIKit

struct GameCenterRank: Equatable {
  let rank: Int
  let totalPlayers: Int
  let formattedScore: String
}

@MainActor
final class GameCenterService: NSObject, ObservableObject {
  static let shared = GameCenterService()

  @Published private(set) var isAuthenticated: Bool = false
  @Published private(set) var ranks: [LeaderboardKey: GameCenterRank] = [:]

  override init() {
    super.init()
    GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
      Task { @MainActor in
        guard let self else { return }
        if let error {
          print("Game Center auth error: \(error.localizedDescription)")
        }
        if let viewController {
          self.presentSignIn(viewController)
        }
        self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
      }
    }
  }

  // MARK: - Score submission

  /// Submits the integer score to the leaderboard matching the given bucket.
  /// Fire-and-forget: silent no-op when not authenticated, errors logged.
  /// Game Center keeps only the player's best score per leaderboard.
  func submitScore(
    _ score: Int,
    gameType: GameType,
    mistakeTolerance: MistakeTolerance
  ) {
    guard isAuthenticated else { return }
    let id = Self.leaderboardID(
      for: gameType,
      mistakeTolerance: mistakeTolerance
    )
    GKLeaderboard.submitScore(
      score,
      context: 0,
      player: GKLocalPlayer.local,
      leaderboardIDs: [id]
    ) { [weak self] error in
      if let error {
        print("Game Center submitScore failed for \(id): \(error.localizedDescription)")
        return
      }
      // Refresh the player's rank for this bucket so the inline pill in
      // LeaderboardView is current next time it appears.
      Task { @MainActor in
        await self?.refreshRank(
          for: gameType,
          mistakeTolerance: mistakeTolerance
        )
      }
    }
  }

  // MARK: - Rank fetch

  /// Loads the local player's rank, total player count, and formatted score
  /// for the given bucket from Game Center, and updates `ranks` reactively.
  /// Silent no-op when not authenticated; errors are logged.
  func refreshRank(
    for gameType: GameType,
    mistakeTolerance: MistakeTolerance
  ) async {
    guard isAuthenticated else { return }
    let id = Self.leaderboardID(
      for: gameType,
      mistakeTolerance: mistakeTolerance
    )
    let key = LeaderboardKey(
      gameType: gameType,
      mistakeTolerance: mistakeTolerance
    )

    do {
      let leaderboards = try await GKLeaderboard.loadLeaderboards(IDs: [id])
      guard let leaderboard = leaderboards.first else { return }

      let (localPlayerEntry, _, totalPlayerCount) = try await leaderboard
        .loadEntries(
          for: .global,
          timeScope: .allTime,
          range: NSRange(location: 1, length: 1)
        )

      if let entry = localPlayerEntry {
        ranks[key] = GameCenterRank(
          rank: entry.rank,
          totalPlayers: totalPlayerCount,
          formattedScore: entry.formattedScore
        )
      } else {
        ranks[key] = nil
      }
    } catch {
      print("Game Center refreshRank failed for \(id): \(error.localizedDescription)")
    }
  }

  // MARK: - Native UI presentation

  /// Presents Apple's `GKGameCenterViewController` scoped to the leaderboard
  /// for the given bucket, in `.global` player scope and `.allTime` time
  /// scope. No-op when not authenticated.
  func presentLeaderboard(
    gameType: GameType,
    mistakeTolerance: MistakeTolerance
  ) {
    guard isAuthenticated else { return }
    guard let rootVC = currentRootViewController() else { return }

    let id = Self.leaderboardID(
      for: gameType,
      mistakeTolerance: mistakeTolerance
    )
    let viewController = GKGameCenterViewController(
      leaderboardID: id,
      playerScope: .global,
      timeScope: .allTime
    )
    viewController.gameCenterDelegate = self
    rootVC.present(viewController, animated: true)
  }

  // MARK: - Bucket → leaderboard mapping

  private static func leaderboardID(
    for gameType: GameType,
    mistakeTolerance: MistakeTolerance
  ) -> String {
    switch (gameType, mistakeTolerance) {
    case (.colorOnly, .easy):
      return "tonic.colorrush.leaderboard.coloronly_easy"
    case (.colorOnly, .normal):
      return "tonic.colorrush.leaderboard.coloronly_normal"
    case (.colorOnly, .hard):
      return "tonic.colorrush.leaderboard.coloronly_hard"
    case (.colorAndText, .easy):
      return "tonic.colorrush.leaderboard.colorandtext_easy"
    case (.colorAndText, .normal):
      return "tonic.colorrush.leaderboard.colorandtext_normal"
    case (.colorAndText, .hard):
      return "tonic.colorrush.leaderboard.colorandtext_hard"
    }
  }

  // MARK: - Helpers

  private func presentSignIn(_ viewController: UIViewController) {
    guard let rootVC = currentRootViewController() else { return }
    rootVC.present(viewController, animated: true)
  }

  private func currentRootViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first
    guard var top = scene?.keyWindow?.rootViewController else { return nil }
    while let presented = top.presentedViewController {
      top = presented
    }
    return top
  }
}

extension GameCenterService: GKGameCenterControllerDelegate {
  nonisolated func gameCenterViewControllerDidFinish(
    _ gameCenterViewController: GKGameCenterViewController
  ) {
    Task { @MainActor in
      gameCenterViewController.dismiss(animated: true)
    }
  }
}
