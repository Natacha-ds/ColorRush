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
    // Force the StoreService singleton to initialise so it loads the IAP
    // product and refreshes the entitlement state at app launch.
    _ = StoreService.shared
  }

  var body: some Scene {
    WindowGroup {
      MainTabView()
    }
  }
}
