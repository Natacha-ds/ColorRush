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
    let firstLaunch = LogService.shared.bootstrap()
    AdsService.shared.bootstrap()
    // Force the StoreService singleton to initialise so it loads the IAP
    // product and refreshes the entitlement state at app launch.
    _ = StoreService.shared
    // Same pattern for GameCenterService: kicks off the
    // GKLocalPlayer.authenticateHandler and reports auth state.
    _ = GameCenterService.shared
    LogService.shared.log("app_initialized", [
      "firstLaunch": firstLaunch,
      "hasRemoveAds": StoreService.shared.hasRemoveAds,
    ])
    #if DEBUG
    CRFontRegistration.verify()
    #endif
  }

  var body: some Scene {
    WindowGroup {
      MainTabView()
    }
  }
}
