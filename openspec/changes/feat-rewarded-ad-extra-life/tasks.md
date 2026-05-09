## 1. Manual setup (Tony)

- [x] 1.1 In **AdMob console → ColorRush app → Ad Units → "+"**, create a new **Rewarded** ad unit named "ColorRush — Extra Life Rewarded". Default eCPM floor / mediation can be left at defaults
- [x] 1.2 Copy the resulting ad unit ID (`ca-app-pub-9259578521352937/2792777342`) and paste it into `AdsService.swift` under the `#else` branch (Release production unit)
- [x] 1.3 No `Info.plist` change — the existing `GADApplicationIdentifier` already covers both interstitial and rewarded formats
- [ ] 1.4 Plan TestFlight validation 24-48h after creating the unit (AdMob warm-up); DEBUG builds use Google's test rewarded ID and serve immediately

## 2. AdsService — rewarded preload + presentation

- [x] 2.1 Add a `rewardedAdUnitID` constant in `AdsService.swift` mirroring the interstitial unit's `#if DEBUG` / `#else` split. DEBUG = `ca-app-pub-3940256099942544/1712485313` (Google's test rewarded). Release = the production ID from task 1.2
- [x] 2.2 Add `@Published private(set) var rewardedReady: Bool = false`
- [x] 2.3 Add `private var rewardedAd: RewardedAd?`
- [x] 2.4 In `startMobileAdsAndPreload()`, kick off both `preloadInterstitial()` and a new `preloadRewardedAd()` concurrently after `MobileAds.shared.start`
- [x] 2.5 Implement `preloadRewardedAd() async`:
  - call `RewardedAd.load(with: rewardedAdUnitID, request: Request())`
  - on success: `rewardedAd = ad; rewardedAd?.fullScreenContentDelegate = self; rewardedReady = true`
  - on failure: log, set `rewardedReady = false`
- [x] 2.6 Implement `func showRewardedAdIfReady(onReward: @escaping () -> Void, onSkip: @escaping () -> Void)`:
  - If `StoreService.shared.hasRemoveAds`: invoke `onReward()` synchronously and return (no ad)
  - Else if `rewardedAd == nil` or no root VC: invoke `onSkip()` and return
  - Else: store `onReward` / `onSkip` references in private optionals (the delegate path needs them on dismiss), then call `rewardedAd.present(from: rootVC) { [weak self] in onReward(); self?.pendingRewardedSkip = nil; self?.pendingRewardedReward = nil }` — the closure runs only when the reward is earned
- [x] 2.7 Extend `FullScreenContentDelegate` so that when the rewarded ad's `adDidDismissFullScreenContent` fires, if the reward closure has not run, invoke `pendingRewardedSkip?()` and clear; either way clear `rewardedAd`, set `rewardedReady = false`, and trigger a fresh `preloadRewardedAd()` task
- [x] 2.8 Decision: distinguishing interstitial vs rewarded inside the shared delegate — use `ad === currentInterstitial` vs `ad === rewardedAd` reference equality, and route cleanup accordingly

## 3. LevelRun — revive flag + grant method

- [x] 3.1 In `LevelSystemModels.swift` `LevelRun`, add `@Published private(set) var hasUsedRewardedRevive: Bool = false` after the existing `@Published` group
- [x] 3.2 Reset it to `false` inside `startRun(...)` and inside `resetRunStats()` (run-level reset)
- [x] 3.3 Add `func grantExtraLife()` that decrements `livesLost` by 1 with a `livesLost = max(0, livesLost - 1)` guard, then sets `hasUsedRewardedRevive = true`
- [x] 3.4 Verify via a quick mental trace that `remainingLives` and `isGameOver` recompute correctly after `grantExtraLife()` is called from a game-over state

## 4. LevelGameOverView — UI hook

- [x] 4.1 Locate `LevelGameOverView` (in `LevelGameView.swift`) and add `@StateObject private var ads = AdsService.shared` plus `@StateObject private var store = StoreService.shared`
- [x] 4.2 Above the existing "Back to Home" button, render a capsule button with:
  - Visibility: `!levelRun.hasUsedRewardedRevive`
  - Title for non-entitled: `"🎬 Continue — Watch Ad"`; for entitled: `"✨ Continue (free)"`
  - Style: capsule, white background, gradient stroke (orange → pink), shadow; opacity 0.5 when disabled
  - Disabled state: non-entitled AND `!ads.rewardedReady`
- [x] 4.3 On tap:
  - Set `levelRun.hasUsedRewardedRevive = true` immediately (one-shot anti-abuse)
  - Call `ads.showRewardedAdIfReady(onReward: { ... }, onSkip: { ... })`
  - `onReward`: call `levelRun.grantExtraLife()`, then call the appropriate level-restart hook so `LevelGameOverView` is dismissed and the level reloads — likely by setting `isLevelFailed = false` and `isLevelComplete = false`, then `startNewLevel()` (mirror the existing `onRetry: { startNewLevel() }` pattern). Verify the dismissal of `LevelGameOverView` happens through this state change
  - `onSkip`: no-op — the player stays on `LevelGameOverView` with only "Back to Home" still visible (the revive button is now hidden because `hasUsedRewardedRevive == true`)
- [x] 4.4 Wrap the callbacks in `Task { @MainActor in ... }` if needed for actor isolation; verify no Swift concurrency warnings

## 5. Validation

- [x] 5.1 `xcodebuild -project ColorGame.xcodeproj -scheme ColorGame -destination 'generic/platform=iOS Simulator' build` returns `BUILD SUCCEEDED`
- [ ] 5.2 Simulator (DEBUG, no Remove Ads entitlement, Hard mode = 1 life): trigger a max-mistake game-over → `LevelGameOverView` shows "🎬 Continue — Watch Ad" (enabled) + "Back to Home". Tap Continue → Google test rewarded ad plays → on close: `livesLost` decrements, level restarts, the rewarded button is gone for the rest of the run
- [ ] 5.3 Simulator (DEBUG, with Remove Ads entitlement granted): same flow but the button reads "✨ Continue (free)" and tapping it skips the ad entirely; one life is granted and the level restarts. Subsequent game-over within the same run shows no "Continue (free)" button
- [ ] 5.4 Skip path: tap Continue → close the ad before earning the reward → verify `hasUsedRewardedRevive == true` and the button does NOT reappear; only "Back to Home" remains
- [ ] 5.5 Cross-run: tap "Back to Home" after a run ends, then start a new run → `hasUsedRewardedRevive == false`, the rewarded button is available again on the next max-mistake game-over
- [ ] 5.6 Regression: complete a normal Easy run (5 lives) without dying → interstitial behavior unchanged (counter increments per level played, fires every 3 transitions). Rewarded preload state is independent and does not interfere

## 6. Commit & archive

- [ ] 6.1 Commit with message `feat: ship rewarded-ad extra-life revive (feat-rewarded-ad-extra-life)`
- [ ] 6.2 No `AUDIT_BUGS.md` entry — feature
- [ ] 6.3 Archive via `/opsx:archive feat-rewarded-ad-extra-life`
