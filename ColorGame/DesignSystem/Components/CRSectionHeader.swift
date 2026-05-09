//
//  CRSectionHeader.swift
//  ColorRush
//

import SwiftUI

struct CRSectionHeader: View {
  let title: String
  var step: String?
  var onBack: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
      if let step {
        Text(step)
          .font(.crLabelUpright)
          .textCase(.uppercase)
          .foregroundStyle(Theme.Colors.textSecondary)
      }
      HStack(spacing: Theme.Spacing.md) {
        if let onBack {
          Button(action: onBack) {
            Image(systemName: "chevron.left")
              .font(.system(size: 18, weight: .bold))
          }
          .buttonStyle(.crIcon)
        }
        Text(title)
          .font(.crHeadline)
          .textCase(.uppercase)
          .foregroundStyle(Theme.Colors.textPrimary)
      }
    }
  }
}
