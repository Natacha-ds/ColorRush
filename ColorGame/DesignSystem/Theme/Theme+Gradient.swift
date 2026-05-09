//
//  Theme+Gradient.swift
//  ColorRush
//

import SwiftUI

extension Theme {
  enum Gradient {
    /// Primary CTA: violet → magenta-pink → cyan, on a slightly tilted axis
    /// (about 17° off horizontal) to break the straight-line feel without
    /// going to a full diagonal.
    static let primary = LinearGradient(
      colors: [
        Theme.Colors.accent,
        Color(hex: 0xD05CFF), // hot magenta-pink mid stop
        Theme.Colors.accentSecondary,
      ],
      startPoint: UnitPoint(x: 0, y: 0.35),
      endPoint: UnitPoint(x: 1, y: 0.65)
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
