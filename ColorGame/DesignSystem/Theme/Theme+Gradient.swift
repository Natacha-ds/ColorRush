//
//  Theme+Gradient.swift
//  ColorRush
//

import SwiftUI

extension Theme {
  enum Gradient {
    /// Primary CTA: 5-stop sweep pipetted from the Figma button renders —
    /// violet → purple → blue → sky → cyan. Full diagonal axis
    /// (topLeading → bottomTrailing) so the band slant is clearly visible
    /// on wide pill buttons.
    static let primary = LinearGradient(
      stops: [
        .init(color: Color(hex: 0x8A48F9), location: 0.0),
        .init(color: Color(hex: 0x6F4DFA), location: 0.25),
        .init(color: Color(hex: 0x4655FD), location: 0.5),
        .init(color: Color(hex: 0x21AEFE), location: 0.75),
        .init(color: Color(hex: 0x00FBFF), location: 1.0),
      ],
      // UnitPoints extended beyond [0,1] vertically to force a visible
      // diagonal slant on wide pill buttons (whose 6:1 aspect would
      // otherwise compress the angle to ≈9° and look horizontal).
      startPoint: UnitPoint(x: 0, y: -2),
      endPoint: UnitPoint(x: 1, y: 3)
    )

    /// Destructive CTA: deep red → bright pink → pink-red, slightly tilted.
    static let danger = LinearGradient(
      colors: [
        Color(hex: 0xC81244),
        Color(hex: 0xFF3D7F), // bright neon pink mid stop
        Theme.Colors.danger,
      ],
      startPoint: UnitPoint(x: 0, y: 0.35),
      endPoint: UnitPoint(x: 1, y: 0.65)
    )

    /// Score progress bar: red → yellow → cyan.
    static let progress = LinearGradient(
      colors: [
        Theme.Colors.danger,
        Theme.Colors.warning,
        Theme.Colors.pro,
        Theme.Colors.accentSecondary,
      ],
      startPoint: .leading,
      endPoint: .trailing
    )

    /// Logo wordmark gradient: white → orange → magenta → cyan.
    static let logo = LinearGradient(
      colors: [
        Theme.Colors.logoWhite,
        Theme.Colors.logoOrange,
        Theme.Colors.logoMagenta,
        Theme.Colors.logoCyan,
      ],
      startPoint: .leading,
      endPoint: .trailing
    )

    /// Header glow under "AMAZING" success state.
    static let headerSuccess = LinearGradient(
      colors: [Color.clear, Theme.Colors.success, Color.clear],
      startPoint: .leading,
      endPoint: .trailing
    )

    /// Header glow under "TOO SLOW" failure state.
    static let headerFailed = LinearGradient(
      colors: [Color.clear, Theme.Colors.warning, Color.clear],
      startPoint: .leading,
      endPoint: .trailing
    )

    /// Game-over background wash (dark red radial feel).
    static let gameOverWash = RadialGradient(
      colors: [Theme.Colors.gameOverWash, Theme.Colors.background],
      center: .center,
      startRadius: 60,
      endRadius: 500
    )
  }
}
