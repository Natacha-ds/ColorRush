//
//  Font+ColorRush.swift
//  ColorRush
//
//  Semantic Montserrat font scale used across the redesigned UI.
//  Call sites must reference Font.cr* — never .custom("Montserrat-...", size:).
//

import SwiftUI

enum CRFontName {
  static let regular = "Montserrat-Regular"
  static let medium = "Montserrat-Medium"
  static let bold = "Montserrat-Bold"
  static let boldItalic = "Montserrat-BoldItalic"
  static let blackItalic = "Montserrat-BlackItalic"
}

extension Font {
  /// 56pt Black (used for hero score numbers like "260" / "95").
  static let crScoreHero = Font.custom(CRFontName.blackItalic, size: 56)

  /// 36pt Black Italic (BEAT 250, AMAZING, TOO SLOW, GAME OVER).
  static let crDisplay = Font.custom(CRFontName.blackItalic, size: 36)

  /// 48pt Black Italic (Color Rush wordmark fallback if image isn't available).
  static let crLogo = Font.custom(CRFontName.blackItalic, size: 48)

  /// 24pt Bold Italic (LEVEL 01, RANKS, screen-level titles).
  static let crTitle = Font.custom(CRFontName.boldItalic, size: 24)

  /// 18pt Bold Italic (PICK A MODE, HOW HARD?, card headlines).
  static let crHeadline = Font.custom(CRFontName.boldItalic, size: 18)

  /// 16pt Bold Italic (button labels, smaller card titles).
  static let crButtonLabel = Font.custom(CRFontName.boldItalic, size: 16)

  /// 14pt Medium (descriptive body copy).
  static let crBody = Font.custom(CRFontName.medium, size: 14)

  /// 13pt Bold (uppercase labels: SCORE, TARGET, TIME, LIVES, HITS).
  static let crLabel = Font.custom(CRFontName.bold, size: 13)

  /// 12pt Medium (captions, small meta).
  static let crCaption = Font.custom(CRFontName.medium, size: 12)

  /// 11pt Bold (tiny pill labels like "Recommended to start").
  static let crPill = Font.custom(CRFontName.bold, size: 11)
}
