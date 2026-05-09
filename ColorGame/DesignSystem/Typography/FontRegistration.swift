//
//  FontRegistration.swift
//  ColorRush
//
//  Debug-only verification that bundled Montserrat weights register correctly.
//  Call CRFontRegistration.verify() once at app launch in DEBUG builds.
//

import UIKit

enum CRFontRegistration {
  static let expectedFontNames: [String] = [
    CRFontName.regular,
    CRFontName.medium,
    CRFontName.bold,
    CRFontName.boldItalic,
    CRFontName.black,
    CRFontName.blackItalic,
  ]

  #if DEBUG
  static func verify() {
    for name in expectedFontNames where UIFont(name: name, size: 12) == nil {
      assertionFailure("[ColorRush] Missing bundled font: \(name). Check Info.plist UIAppFonts and target membership.")
    }
  }
  #endif
}
