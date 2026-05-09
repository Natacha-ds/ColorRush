//
//  PrimaryGradientButtonStyle.swift
//  ColorRush
//

import SwiftUI

struct PrimaryGradientButtonStyle: ButtonStyle {
  var fillsWidth: Bool = true

  func makeBody(configuration: Configuration) -> some View {
    let shape = Capsule(style: .continuous)
    return configuration.label
      .font(.crButtonLabel)
      .foregroundStyle(Theme.Colors.textPrimary)
      .textCase(.uppercase)
      .frame(maxWidth: fillsWidth ? .infinity : nil)
      .padding(.vertical, Theme.Spacing.lg)
      .padding(.horizontal, Theme.Spacing.xl)
      .background(shape.fill(Theme.Gradient.primary))
      .crShadow(Theme.Shadow.elevated)
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .opacity(configuration.isPressed ? 0.92 : 1.0)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}
