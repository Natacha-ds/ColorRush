//
//  Font+ColorRush.swift
//  ColorRush
//
//  Semantic Montserrat font scale used across the redesigned UI.
//  Call sites must reference Font.cr* — never .custom("Montserrat-...", size:).
//
//  The Figma design uses italic Montserrat for titles, card titles, and
//  descriptions. Upright (non-italic) is reserved for select call sites where
//  italics don't read well (e.g., the PLAY button label uses .crButtonLabel).
//

import SwiftUI

enum CRFontName {
  static let regular = "Montserrat-Regular"
  static let italic = "Montserrat-Italic"
  static let medium = "Montserrat-Medium"
  static let mediumItalic = "Montserrat-MediumItalic"
  static let bold = "Montserrat-Bold"
  static let boldItalic = "Montserrat-BoldItalic"
  static let black = "Montserrat-Black"
  static let blackItalic = "Montserrat-BlackItalic"
}

extension Font {
  /// 56pt Black Italic — hero score numbers ("260" / "95").
  static let crScoreHero = Font.custom(CRFontName.blackItalic, size: 56)

  /// 36pt Black Italic — display headlines (BEAT 250, AMAZING, TOO SLOW, GAME OVER).
  static let crDisplay = Font.custom(CRFontName.blackItalic, size: 36)

  /// 48pt Black Italic — Color Rush wordmark fallback if image isn't available.
  static let crLogo = Font.custom(CRFontName.blackItalic, size: 48)

  /// 24pt Bold Italic — screen-level titles (LEVEL 01, RANKS, HOW HARD?, PICK A MODE).
  static let crTitle = Font.custom(CRFontName.boldItalic, size: 24)

  /// 18pt Bold Italic — card headlines (Color ONLY, ROOKIE, etc.).
  static let crHeadline = Font.custom(CRFontName.boldItalic, size: 18)

  /// 16pt Bold (NOT italic) — primary CTA button labels (PLAY, CONTINUE, LET'S GO).
  static let crButtonLabel = Font.custom(CRFontName.bold, size: 16)

  /// 14pt Medium Italic — descriptive body copy.
  static let crBody = Font.custom(CRFontName.mediumItalic, size: 14)

  /// 13pt Bold Italic — uppercase small labels (BEST, STEP 1/2, SCORE, TARGET).
  static let crLabel = Font.custom(CRFontName.boldItalic, size: 13)

  /// 12pt Medium Italic — captions, small meta text.
  static let crCaption = Font.custom(CRFontName.mediumItalic, size: 12)

  /// 11pt Bold Italic — tiny pill labels (Recommended to start).
  static let crPill = Font.custom(CRFontName.boldItalic, size: 11)

  // MARK: - Upright variants
  //
  // The redesign uses italic Montserrat by default for titles, labels, and
  // body copy. A few screens (e.g., Home) call for upright (non-italic)
  // typography per the Figma source. These mirror the italic scale but use
  // the Bold / Black / Medium variants without slant.

  /// 24pt Bold (upright) — screen titles on Home / non-italic surfaces.
  static let crTitleUpright = Font.custom(CRFontName.bold, size: 24)

  /// 18pt Bold (upright) — headlines on non-italic surfaces.
  static let crHeadlineUpright = Font.custom(CRFontName.bold, size: 18)

  /// 14pt Medium (upright) — body copy on non-italic surfaces.
  static let crBodyUpright = Font.custom(CRFontName.medium, size: 14)

  /// 13pt Bold (upright) — small labels on non-italic surfaces (BEST).
  static let crLabelUpright = Font.custom(CRFontName.bold, size: 13)

  /// 12pt Medium (upright) — captions on non-italic surfaces.
  static let crCaptionUpright = Font.custom(CRFontName.medium, size: 12)
}
