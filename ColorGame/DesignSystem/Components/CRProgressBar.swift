//
//  CRProgressBar.swift
//  ColorRush
//

import SwiftUI

struct CRProgressBar: View {
  /// Value in 0...1. Out-of-range inputs are clamped.
  let progress: Double

  var height: CGFloat = 6

  private var clamped: Double { min(1.0, max(0.0, progress)) }

  var body: some View {
    GeometryReader { geo in
      ZStack(alignment: .leading) {
        Capsule(style: .continuous)
          .fill(Theme.Colors.surfaceElevated)
        Capsule(style: .continuous)
          .fill(Theme.Gradient.progress)
          .frame(width: geo.size.width * CGFloat(clamped))
          .animation(.easeOut(duration: 0.35), value: clamped)
      }
    }
    .frame(height: height)
  }
}
