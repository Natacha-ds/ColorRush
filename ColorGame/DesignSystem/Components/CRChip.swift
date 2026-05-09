//
//  CRChip.swift
//  ColorRush
//

import SwiftUI

struct CRChip: View {
  enum Tone {
    case neutral
    case accent
    case success
    case warning
    case danger

    var foreground: Color {
      switch self {
      case .neutral: return Theme.Colors.textPrimary
      case .accent: return Theme.Colors.accentSecondary
      case .success: return Theme.Colors.success
      case .warning: return Theme.Colors.warning
      case .danger: return Theme.Colors.danger
      }
    }

    var background: Color {
      switch self {
      case .neutral: return Theme.Colors.surfaceElevated
      case .accent: return Theme.Colors.accentSecondary.opacity(0.18)
      case .success: return Theme.Colors.success.opacity(0.18)
      case .warning: return Theme.Colors.warning.opacity(0.18)
      case .danger: return Theme.Colors.danger.opacity(0.18)
      }
    }
  }

  let title: String
  var icon: Image?
  var tone: Tone = .neutral

  var body: some View {
    HStack(spacing: Theme.Spacing.xs) {
      if let icon {
        icon
          .renderingMode(.template)
      }
      Text(title)
        .font(.crPill)
        .textCase(.uppercase)
    }
    .foregroundStyle(tone.foreground)
    .padding(.vertical, Theme.Spacing.xs + 2)
    .padding(.horizontal, Theme.Spacing.md)
    .background(
      Capsule(style: .continuous)
        .fill(tone.background)
    )
  }
}
