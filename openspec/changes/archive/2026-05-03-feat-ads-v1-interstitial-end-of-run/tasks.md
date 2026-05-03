## 1. Manual setup (Tony)

- [x] 1.1 SPM dependency `googleads/swift-package-manager-google-mobile-ads` added to the `ColorGame` target via Xcode UI (visible in `project.pbxproj`: `GoogleMobileAds` in `packageProductDependencies` and the `Frameworks` build phase)
- [x] 1.2 AdMob console: App ID `ca-app-pub-9259578521352937~8432033718` and interstitial Ad Unit ID `ca-app-pub-9259578521352937/6262225438` confirmed active
- [x] 1.3 GDPR consent message configured in AdMob (Privacy & messaging → GDPR). Decision: ship v1 with GDPR-only message; US/CCPA message tracked as a post-launch backlog item

## 2. Info.plist — manual

- [x] 2.1 Switched the project off `GENERATE_INFOPLIST_FILE` and onto a manual `Info.plist` at the project root (since `INFOPLIST_KEY_*` build settings don't support array-of-dict types like `SKAdNetworkItems`). Manual file holds: `CFBundle*` keys via `$(VAR)` substitution, `UIApplicationSceneManifest`, `UILaunchScreen`, `UIStatusBarStyle`, supported orientations (iPhone + iPad), `LSRequiresIPhoneOS`, `GADApplicationIdentifier` = `ca-app-pub-9259578521352937~8432033718`, and 47 `SKAdNetworkItems` (≈70 in Google's full list — Tony can sync with the latest from the AdMob docs as a polish pass)
- [x] 2.2 Verified `CFBundleIdentifier` and `GADApplicationIdentifier` end up in the built `.app/Info.plist` via `plutil -p`
- [x] 2.3 Info.plist file lives outside the synchronized `ColorGame/` group to avoid being double-processed (would otherwise be added to Copy Bundle Resources)

## 3. AdsService implementation

- [x] 3.1 Created `ColorGame/AdsService.swift` — `@MainActor final class` singleton with UMP consent flow, Mobile Ads init, interstitial preload, frequency-capped presentation, dismissal callback, and `FullScreenContentDelegate` conformance
- [x] 3.2 DEBUG/Release split for the ad unit ID: test ID in DEBUG, real production ID in Release
- [x] 3.3 `@Published private(set) var isReady: Bool` (added `import Combine` for `@Published` on a `@MainActor` class)
- [x] 3.4 In-memory frequency counter (`runsSinceLastAd`, cap = 3); resets on app launch (no persistence)
- [x] 3.5 `bootstrap()` method: kicks off UMP consent, then starts Mobile Ads SDK and preloads first interstitial
- [x] 3.6 `showInterstitialIfReady(onDismiss:)` always invokes `onDismiss` — either after ad dismissal, on cap miss, on missing host VC, or on presentation failure
- [x] 3.7 Helper `currentRootViewController()` to bridge to UIKit for ad presentation
- [x] 3.8 In DEBUG, `UMPDebugSettings.geography = .EEA` to force the consent form during simulator testing

## 4. App-level wiring

- [x] 4.1 `ColorGameApp.init()` calls `AdsService.shared.bootstrap()` so consent + SDK init kicks off at app launch

## 5. End-of-run integration in LevelGameView

- [x] 5.1 In-game Back chevron: navigation post wrapped in `AdsService.shared.showInterstitialIfReady { … }`
- [x] 5.2 `LevelFailedView.onBackToHome`: same wrapping pattern
- [x] 5.3 `LevelCompleteView.onBackToHome`: same wrapping pattern
- [x] 5.4 `LevelGameOverView.onBackToHome`: same wrapping pattern
- [x] 5.5 `FinalWinView.onPlayHarder`: `dismiss()` wrapped (single-line dismissal kept inside the ad gate)
- [x] 5.6 `FinalWinView.onSeeLeaderboard`: `dismiss()` + `SwitchToLeaderboard` post wrapped together inside one ad gate

## 6. Validation

- [x] 6.1 `xcodebuild ... build` returns `BUILD SUCCEEDED` after the SPM addition + AdsService + wiring
- [x] 6.2 Device test (first launch): UMP consent form rendered correctly; SDK initialised; first interstitial preloaded successfully
- [x] 6.3 Device test (cap + present): on the 3rd end-of-run event, the test interstitial presented and dismissed cleanly. Tony confirmed live from his iPhone after fixing the `currentRootViewController()` walk-up-the-presentation-chain bug (initial code returned the root tab VC which was already presenting `LevelGameView`, producing AdMob error code 17 "view controller already presenting another view controller")
- [x] 6.4 Tested implicitly through the device test
- [x] 6.5 BUG-022 cascade still functions on every end-of-run path; no regression observed

## 7. Commit & archive

- [x] 7.1 Commit `e804009 feat: ship v1 interstitial ads at end of run (feat-ads-v1)`
- [x] 7.2 No AUDIT_BUGS.md entry — feature
- [x] 7.3 Archived via `/opsx:archive` to `2026-05-03-feat-ads-v1-interstitial-end-of-run`
