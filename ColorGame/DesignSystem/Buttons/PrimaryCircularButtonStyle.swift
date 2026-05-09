//
//  PrimaryCircularButtonStyle.swift
//  ColorRush
//
//  Circular variant of the primary CTA — used for the Home screen PLAY button.
//  The button is a STROKED gradient ring (not a filled disc), with content
//  centered inside. Matches Frame 1.
//

import SwiftUI

struct PrimaryCircularButtonStyle: ButtonStyle {
  var diameter: CGFloat = 200
  var lineWidth: CGFloat = 6

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(Theme.Colors.textPrimary)
      .textCase(.uppercase)
      .frame(width: diameter, height: diameter)
      .background(
        Circle()
          .strokeBorder(Theme.Gradient.primary, lineWidth: lineWidth)
      )
      .contentShape(Circle())
      .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
      .opacity(configuration.isPressed ? 0.92 : 1.0)
      .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
  }
}
