//
//  CRStatBadge.swift
//  ColorRush
//
//  Single labeled stat tile (Hits / Misses / Streak end-of-level summary).
//

import SwiftUI

struct CRStatBadge: View {
  enum Tone {
    case success
    case warning
    case info
    case neutral

    var color: Color {
      switch self {
      case .success: return Theme.Colors.success
      case .warning: return Theme.Colors.warning
      case .info: return Theme.Colors.accentSecondary
      case .neutral: return Theme.Colors.textPrimary
      }
    }
  }

  let label: String
  let value: String
  var tone: Tone = .neutral

  var body: some View {
    VStack(spacing: Theme.Spacing.xs) {
      Text(label)
        .font(.crLabel)
        .textCase(.uppercase)
        .foregroundStyle(Theme.Colors.textSecondary)
      Text(value)
        .font(.crTitle)
        .foregroundStyle(tone.color)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, Theme.Spacing.lg)
    .background(
      RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        .fill(Theme.Colors.surface)
    )
  }
}
