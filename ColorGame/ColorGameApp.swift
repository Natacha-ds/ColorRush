//
//  ColorGameApp.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import Sentry
import SwiftUI

@main
struct ColorRushApp: App {
  init() {
    Self.bootstrapSentry()
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

  /// Crash-only Sentry. We disable performance, app-hang detection, auto
  /// session tracking and swizzling to keep this lean and quiet. DEBUG
  /// builds skip Sentry entirely so dev runs don't pollute the prod
  /// project.
  private static func bootstrapSentry() {
    #if DEBUG
      return
    #else
      SentrySDK.start { options in
        options.dsn =
          "https://cc4b1c5ab695783356bfe23abbec1499@o4510124195708928.ingest.de.sentry.io/4511366458769488"
        options.environment = "production"
        options.enableAutoSessionTracking = false
        options.enableAppHangTracking = false
        options.enableSwizzling = false
        options.tracesSampleRate = 0
        options.profilesSampleRate = 0
      }
    #endif
  }

  var body: some Scene {
    WindowGroup {
      MainTabView()
    }
  }
}
