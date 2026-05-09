//
//  Theme+Colors.swift
//  ColorRush
//

import SwiftUI

extension Theme {
  enum Colors {
    // Backgrounds
    static let background = Color(hex: 0x000000)
    static let surface = Color(hex: 0x161616)
    static let surfaceElevated = Color(hex: 0x262626)
    static let border = Color(hex: 0x2A2A2A)
    static let borderStrong = Color(hex: 0x3A3A3A)

    // Text
    static let textPrimary = Color(hex: 0xFFFFFF)
    static let textSecondary = Color(hex: 0x9CA3AF)
    static let textMuted = Color(hex: 0x6B7280)

    // Brand accents (primary gradient stops)
    static let accent = Color(hex: 0x8F46F8) // violet
    static let accentSecondary = Color(hex: 0x3DD3FF) // cyan

    // Semantic — also drive difficulty cues, stat tones, hearts.
    /// Green. Used for: success states, Rookie difficulty cue, green tile, Hits stat.
    static let success = Color(hex: 0x3DFF57)
    /// Orange. Used for: warning states, level-failed header, Misses stat.
    static let warning = Color(hex: 0xF29924)
    /// Pink-red. Used for: danger states, Insane difficulty cue, hearts.
    static let danger = Color(hex: 0xEC0955)
    /// Warm gold. Used for: Pro difficulty cue, yellow tile, leader badge.
    static let pro = Color(hex: 0xFDE16F)

    // Logo gradient stops
    static let logoWhite = Color(hex: 0xFFFFFF)
    static let logoOrange = Color(hex: 0xF29924)
    static let logoMagenta = Color(hex: 0xEC0955)
    static let logoCyan = Color(hex: 0x3DD3FF)

    // Game-over wash
    static let gameOverWash = Color(hex: 0x3A0A1A)

    /// Color tokens for the four gameplay tiles. Green and yellow are aliases
    /// of the corresponding semantic tokens; red and blue are distinct.
    enum Tile {
      static let red = Color(hex: 0xE94545)
      static let blue = Color(hex: 0x2563EB)
      static let green = Theme.Colors.success
      static let yellow = Theme.Colors.pro
    }
  }
}
