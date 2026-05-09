//
//  CRCard.swift
//  ColorRush
//

import SwiftUI

struct CRCard<InnerContent: View>: View {
  enum BorderStyle {
    case none
    case subtle
    case accent(Color)
  }

  var padding: CGFloat = Theme.Spacing.xl
  var borderStyle: BorderStyle = .subtle
  var hasShadow: Bool = false
  let content: InnerContent

  init(
    padding: CGFloat = Theme.Spacing.xl,
    borderStyle: BorderStyle = .subtle,
    hasShadow: Bool = false,
    @ViewBuilder content: () -> InnerContent
  ) {
    self.padding = padding
    self.borderStyle = borderStyle
    self.hasShadow = hasShadow
    self.content = content()
  }

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
    return content
      .padding(padding)
      .background(shape.fill(Theme.Colors.surface))
      .overlay(borderOverlay)
      .shadow(
        color: hasShadow ? Theme.Shadow.card.color : .clear,
        radius: hasShadow ? Theme.Shadow.card.radius : 0,
        x: hasShadow ? Theme.Shadow.card.x : 0,
        y: hasShadow ? Theme.Shadow.card.y : 0
      )
  }

  @ViewBuilder
  private var borderOverlay: some View {
    switch borderStyle {
    case .none:
      EmptyView()
    case .subtle:
      RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
        .strokeBorder(Theme.Colors.border, lineWidth: 1)
    case let .accent(color):
      RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
        .strokeBorder(color, lineWidth: 2)
    }
  }
}
