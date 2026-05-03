//
//  ColorGameApp.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import SwiftUI

@main
struct ColorRushApp: App {
  init() {
    AdsService.shared.bootstrap()
  }

  var body: some Scene {
    WindowGroup {
      MainTabView()
    }
  }
}
