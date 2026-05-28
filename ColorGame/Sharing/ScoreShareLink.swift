import SwiftUI

enum ShareSource: String {
  case gameOver = "game_over"
  case leaderboard
}

private let shareAppStoreURL = "https://apps.apple.com/app/id6766084527"

@MainActor
struct ScoreShareLink<Label: View>: View {
  let score: Int
  let gameType: GameType
  let mistakeTolerance: MistakeTolerance
  let source: ShareSource
  let accessibilityLabel: LocalizedStringKey
  @ViewBuilder var label: () -> Label

  private var messageText: String {
    String(localized: "I scored \(score.formatted()) points on ColorRush. Can you beat me? \(shareAppStoreURL)")
  }

  private var renderedImage: Image? {
    let renderer = ImageRenderer(
      content: ShareableScoreBadge(
        score: score,
        gameType: gameType,
        mistakeTolerance: mistakeTolerance
      )
    )
    renderer.scale = 2.0
    return renderer.uiImage.map { Image(uiImage: $0) }
  }

  var body: some View {
    Group {
      if let image = renderedImage {
        ShareLink(
          item: image,
          message: Text(messageText),
          preview: SharePreview(messageText, image: image),
          label: label
        )
        .simultaneousGesture(TapGesture().onEnded { logTap() })
      } else {
        Button(action: {}, label: label).disabled(true)
      }
    }
    .accessibilityLabel(accessibilityLabel)
  }

  private func logTap() {
    LogService.shared.log("share_tapped", [
      "source": source.rawValue,
      "score": score,
      "gameType": gameType.rawValue,
      "mistakeTolerance": mistakeTolerance.rawValue,
    ])
  }
}
