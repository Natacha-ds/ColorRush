//
//  HapticsService.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

#if canImport(UIKit)
  import UIKit
#endif

class HapticsService {
  static let shared = HapticsService()

  #if canImport(UIKit)
    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let heavyGenerator = UIImpactFeedbackGenerator(style: .heavy)
  #endif

  private init() {}

  func lightImpact() {
    #if canImport(UIKit)
      lightGenerator.impactOccurred()
    #endif
  }

  func heavyImpact() {
    #if canImport(UIKit)
      heavyGenerator.impactOccurred()
    #endif
  }
}
