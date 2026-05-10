//
//  IconButtonStyle.swift
//  ColorRush
//

import SwiftUI

struct IconButtonStyle: ButtonStyle {
  var tint: Color = Theme.Colors.textPrimary
  var size: CGFloat = 44

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .foregroundStyle(tint)
      .frame(minWidth: size, minHeight: size)
      .contentShape(Rectangle())
      .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
      .opacity(configuration.isPressed ? 0.7 : 1.0)
      .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
      .clickSound(.secondary, isPressed: configuration.isPressed)
  }
}
