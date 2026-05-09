//
//  CRHeartsPill.swift
//  ColorRush
//
//  Pill rendering the remaining hearts (filled) followed by the spent ones
//  (dimmed) and a numeric count, matching the gameplay HUD.
//

import SwiftUI

struct CRHeartsPill: View {
  let remaining: Int
  let total: Int

  private var clampedRemaining: Int { max(0, min(remaining, total)) }

  var body: some View {
    HStack(spacing: Theme.Spacing.xs) {
      ForEach(0..<total, id: \.self) { index in
        Image(systemName: "heart.fill")
          .font(.system(size: 12, weight: .bold))
          .foregroundStyle(index < clampedRemaining ? Theme.Colors.danger : Theme.Colors.danger.opacity(0.18))
      }
      Text("\(clampedRemaining)")
        .font(.crLabel)
        .foregroundStyle(Theme.Colors.textPrimary)
        .padding(.leading, Theme.Spacing.xs)
    }
    .padding(.vertical, Theme.Spacing.xs + 2)
    .padding(.horizontal, Theme.Spacing.md)
    .background(
      Capsule(style: .continuous)
        .fill(Theme.Colors.surfaceElevated)
    )
  }
}
