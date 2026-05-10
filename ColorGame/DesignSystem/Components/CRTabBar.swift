//
//  CRTabBar.swift
//  ColorRush
//
//  Custom bottom navigation chrome shared by Home and Leaderboard.
//  Uses iOS 26 Liquid Glass effect for the pill background.
//

import SwiftUI

struct CRTabBarItem: Identifiable {
  let id: Int
  let icon: Image
  let selectedTint: Color
  let accessibilityLabel: String
}

struct CRTabBar: View {
  let items: [CRTabBarItem]
  @Binding var selection: Int

  var body: some View {
    HStack {
      Spacer()
      pill
      Spacer()
    }
    .padding(.top, Theme.Spacing.sm)
    .padding(.bottom, Theme.Spacing.md)
  }

  private var pill: some View {
    HStack(spacing: Theme.Spacing.xxxl) {
      ForEach(items) { item in
        Button {
          selection = item.id
        } label: {
          item.icon
            .font(.system(size: 26, weight: .bold))
            .foregroundStyle(item.selectedTint)
            .opacity(selection == item.id ? 1.0 : 0.4)
        }
        .buttonStyle(.crIcon(tint: item.selectedTint, size: 48))
        .accessibilityLabel(item.accessibilityLabel)
      }
    }
    .padding(.horizontal, Theme.Spacing.lg)
    .padding(.vertical, Theme.Spacing.xs)
    .glassEffect(
      .regular.tint(Theme.Colors.surfaceElevated.opacity(0.5)),
      in: Capsule(style: .continuous)
    )
  }
}
