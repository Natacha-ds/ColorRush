import SwiftUI

struct ShareableScoreBadge: View {
  let score: Int
  let gameType: GameType
  let mistakeTolerance: MistakeTolerance

  private static let badgeSize: CGFloat = 1080

  private var difficultyTone: Color {
    switch mistakeTolerance {
    case .easy: Theme.Colors.success
    case .normal: Theme.Colors.pro
    case .hard: Theme.Colors.danger
    }
  }

  var body: some View {
    ZStack {
      Theme.Colors.background

      RadialGradient(
        colors: [difficultyTone.opacity(0.35), Theme.Colors.background],
        center: .center,
        startRadius: 80,
        endRadius: 700
      )

      VStack(spacing: 0) {
        Spacer().frame(height: 80)

        Image("CRLogo")
          .resizable()
          .renderingMode(.original)
          .aspectRatio(contentMode: .fit)
          .frame(height: 140)

        Spacer().frame(height: 36)

        Text("DON'T TAP THE ANNOUNCED COLOR")
          .font(Font.custom(CRFontName.boldItalic, size: 42))
          .foregroundStyle(Theme.Colors.textSecondary)
          .tracking(2)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 60)

        Spacer().frame(height: 36)

        HStack(spacing: 22) {
          tileSwatch(.red, forbidden: true)
          tileSwatch(.blue, forbidden: false)
          tileSwatch(.green, forbidden: false)
          tileSwatch(.yellow, forbidden: false)
        }

        Spacer()

        Text(verbatim: "\(score.formatted())")
          .font(Font.custom(CRFontName.blackItalic, size: 280))
          .foregroundStyle(Theme.Colors.logoWhite)
          .minimumScaleFactor(0.5)
          .lineLimit(1)
          .padding(.horizontal, 80)

        Spacer().frame(height: 14)

        HStack(spacing: 24) {
          Text(gameType.brandLabel)
            .foregroundStyle(Theme.Colors.logoWhite)
          Text(verbatim: "·")
            .foregroundStyle(difficultyTone)
          Text(mistakeTolerance.brandLabel)
            .foregroundStyle(difficultyTone)
        }
        .font(Font.custom(CRFontName.boldItalic, size: 64))
        .tracking(3)

        Spacer()

        Text("BEAT ME")
          .font(Font.custom(CRFontName.blackItalic, size: 72))
          .foregroundStyle(Theme.Colors.logoWhite)
          .tracking(5)
          .padding(.vertical, 26)
          .padding(.horizontal, 64)
          .background(
            Capsule(style: .continuous)
              .fill(difficultyTone)
          )

        Spacer().frame(height: 80)
      }
    }
    .frame(width: Self.badgeSize, height: Self.badgeSize)
  }

  private func tileSwatch(_ color: Color, forbidden: Bool) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 26, style: .continuous)
        .fill(color)
        .frame(width: 130, height: 130)
        .overlay(
          RoundedRectangle(cornerRadius: 26, style: .continuous)
            .strokeBorder(Theme.Colors.logoWhite.opacity(0.15), lineWidth: 3)
        )

      if forbidden {
        Image(systemName: "xmark")
          .font(.system(size: 76, weight: .black))
          .foregroundStyle(Theme.Colors.logoWhite)
          .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 2)
      }
    }
  }
}

#Preview("Low · COLOR · ROOKIE") {
  ShareableScoreBadge(score: 120, gameType: .colorOnly, mistakeTolerance: .easy)
    .scaleEffect(0.3)
    .frame(width: 324, height: 324)
}

#Preview("High · COLOR+WORD · MASTER") {
  ShareableScoreBadge(score: 9999, gameType: .colorAndText, mistakeTolerance: .hard)
    .scaleEffect(0.3)
    .frame(width: 324, height: 324)
}

#Preview("Mid · COLOR · PRO") {
  ShareableScoreBadge(score: 1420, gameType: .colorOnly, mistakeTolerance: .normal)
    .scaleEffect(0.3)
    .frame(width: 324, height: 324)
}
