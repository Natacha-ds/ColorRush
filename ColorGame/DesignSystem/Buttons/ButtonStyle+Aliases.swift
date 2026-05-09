//
//  ButtonStyle+Aliases.swift
//  ColorRush
//
//  Convenience static accessors so call sites read
//  `.buttonStyle(.crPrimary)` instead of constructing the struct.
//

import SwiftUI

extension ButtonStyle where Self == PrimaryGradientButtonStyle {
  static var crPrimary: PrimaryGradientButtonStyle { PrimaryGradientButtonStyle() }

  static func crPrimary(fillsWidth: Bool) -> PrimaryGradientButtonStyle {
    PrimaryGradientButtonStyle(fillsWidth: fillsWidth)
  }
}

extension ButtonStyle where Self == PrimaryCircularButtonStyle {
  static var crPrimaryCircular: PrimaryCircularButtonStyle { PrimaryCircularButtonStyle() }

  static func crPrimaryCircular(diameter: CGFloat) -> PrimaryCircularButtonStyle {
    PrimaryCircularButtonStyle(diameter: diameter)
  }
}

extension ButtonStyle where Self == DangerGradientButtonStyle {
  static var crDanger: DangerGradientButtonStyle { DangerGradientButtonStyle() }

  static func crDanger(fillsWidth: Bool) -> DangerGradientButtonStyle {
    DangerGradientButtonStyle(fillsWidth: fillsWidth)
  }
}

extension ButtonStyle where Self == IconButtonStyle {
  static var crIcon: IconButtonStyle { IconButtonStyle() }

  static func crIcon(tint: Color, size: CGFloat = 44) -> IconButtonStyle {
    IconButtonStyle(tint: tint, size: size)
  }
}
