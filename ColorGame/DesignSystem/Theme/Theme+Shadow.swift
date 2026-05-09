//
//  Theme+Shadow.swift
//  ColorRush
//

import SwiftUI

extension Theme {
  enum Shadow {
    struct Style {
      let color: Color
      let radius: CGFloat
      let x: CGFloat
      let y: CGFloat
    }

    /// Soft elevation under primary buttons / floating elements.
    static let elevated = Style(
      color: Color.black.opacity(0.45),
      radius: 18,
      x: 0,
      y: 8
    )

    /// Subtle lift under surface cards.
    static let card = Style(
      color: Color.black.opacity(0.35),
      radius: 12,
      x: 0,
      y: 4
    )

    /// Glow used for "amazing" / lightning bolt success affordances.
    static let successGlow = Style(
      color: Theme.Colors.success.opacity(0.55),
      radius: 24,
      x: 0,
      y: 0
    )

    /// Glow used for danger / game-over affordances.
    static let dangerGlow = Style(
      color: Theme.Colors.danger.opacity(0.55),
      radius: 24,
      x: 0,
      y: 0
    )
  }
}

extension View {
  func crShadow(_ style: Theme.Shadow.Style) -> some View {
    shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
  }
}
