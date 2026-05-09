# ads Specification

## Purpose
TBD - created by archiving change feat-ads-v1-interstitial-end-of-run. Update Purpose after archive.
## Requirements
### Requirement: A "level played" counter drives interstitial frequency

The app SHALL increment an in-memory "levels played" counter on `AdsService` each time a level finishes — either successfully (`isLevelComplete` flips to `true`) or unsuccessfully (`isLevelFailed` flips to `true`). The counter SHALL reset to zero on app launch.

#### Scenario: Counter increments on level complete

- **WHEN** the player finishes a level by reaching the required score and `isLevelComplete` flips to `true`
- **THEN** `AdsService.recordLevelPlayed()` is invoked exactly once, incrementing the counter

#### Scenario: Counter increments on level failed

- **WHEN** the player finishes a level by losing all lives or by missing the required score, and `isLevelFailed` flips to `true`
- **THEN** `AdsService.recordLevelPlayed()` is invoked exactly once, incrementing the counter

### Requirement: Interstitial is presented at the next user navigation when the cap is reached

When the player triggers a navigation event in `LevelGameView` (in-game Back, level-failed Back to Home, level-complete Back to Home, level-complete Next Level, level-failed Retry, level-game-over Back to Home, FinalWin play-harder, FinalWin see-leaderboard), the app SHALL invoke `AdsService.showInterstitialIfReady(onDismiss:)`. The method SHALL present the interstitial only if the "levels played" counter has reached the cap; the counter SHALL NOT be mutated by this method itself (incrementing is the responsibility of the level-end hook).

#### Scenario: Navigation when the cap has been reached

- **WHEN** the player taps a navigation button and the counter is ≥ 3
- **THEN** the interstitial is presented, the counter resets to zero, and the navigation continuation runs from the `onDismiss` callback after the ad is dismissed

#### Scenario: Navigation when the cap is not yet reached

- **WHEN** the player taps a navigation button and the counter is < 3
- **THEN** no ad is presented, the counter is unchanged, and the `onDismiss` callback runs immediately

### Requirement: Interstitial frequency cap

The interstitial ad SHALL be presented at most once every three levels played.

#### Scenario: Three levels played trigger one ad on the next navigation

- **WHEN** the player completes or fails three levels in a single launch and then taps a navigation button
- **THEN** the interstitial is presented exactly once, the counter resets to zero, and the next presentation is gated by another three levels played

### Requirement: End-of-run flow is robust to ad failures

The end-of-run flow (score save, run reset, navigation back to Home) SHALL complete deterministically regardless of whether the ad presented, was skipped by the cap, failed to load, or failed to present. The `onDismiss` callback SHALL always fire.

#### Scenario: Ad fails to load

- **WHEN** an end-of-run event fires but the pre-loaded interstitial is missing or expired
- **THEN** no ad is presented, the `onDismiss` callback runs immediately, and the `DismissToHome` cascade still runs

#### Scenario: Ad fails to present

- **WHEN** the SDK reports a presentation failure mid-flow
- **THEN** the `onDismiss` callback runs from the failure delegate, and the `DismissToHome` cascade still runs

### Requirement: Mobile Ads SDK initializes only after UMP consent has resolved

The Google Mobile Ads SDK SHALL be started only after the UMP (User Messaging Platform) consent flow has resolved (granted, denied, or skipped where the user is not in a consent-required jurisdiction). No ad request SHALL be made before this resolution.

#### Scenario: First launch in a consent-required jurisdiction

- **WHEN** the player launches the app for the first time and the UMP consent form appears
- **THEN** Mobile Ads SDK initialization waits for the consent form to be dismissed (regardless of choice) before proceeding to start the SDK and pre-load the first ad

#### Scenario: Subsequent launches with valid stored consent

- **WHEN** the player launches the app and a valid stored consent state is available
- **THEN** the UMP flow resolves silently and the SDK initializes immediately; no consent form is shown

### Requirement: Test ad units in DEBUG, real ad units in Release

The interstitial ad unit ID SHALL be Google's documented test ID in DEBUG builds and the project's real production ID in Release builds, controlled by `#if DEBUG`.

#### Scenario: A DEBUG simulator build presents test ads only

- **WHEN** a developer runs the app from Xcode in DEBUG configuration
- **THEN** the SDK requests ads using Google's test interstitial ID; real ad units are never used in this build configuration

### Requirement: Interstitial is suppressed when the Remove Ads entitlement is held

Both `AdsService.recordLevelPlayed()` and `AdsService.showInterstitialIfReady(onDismiss:)` SHALL early-return (the latter invoking `onDismiss()` immediately) when the player holds the Remove Ads entitlement (`StoreService.shared.hasRemoveAds == true`). The "levels played" counter SHALL NOT advance while the entitlement is held, so a player whose entitlement later lapses does not see a backlog of "owed" ads.

#### Scenario: Entitled player finishes a level

- **WHEN** an entitled player finishes a level (complete or failed)
- **THEN** the counter does NOT advance and no interstitial is queued

#### Scenario: Entitled player triggers a navigation

- **WHEN** an entitled player taps any navigation button
- **THEN** no interstitial is presented, `onDismiss()` is invoked immediately, and the counter is unchanged

#### Scenario: Entitlement loss reverts to ad gate

- **WHEN** an entitled player loses the entitlement (e.g., refund) mid-session
- **THEN** the next level-finished event resumes incrementing the counter, starting from whatever value the cap reset last left it at

### Requirement: A rewarded ad is preloaded at app bootstrap

After UMP consent has resolved and `MobileAds.shared.start` has completed, the app SHALL preload a rewarded ad via `RewardedAd.load(with:request:)`. The preload state SHALL be exposed reactively via `AdsService.rewardedReady` so SwiftUI views can disable the revive CTA until the rewarded ad is ready. After every successful presentation, the next rewarded ad SHALL be preloaded automatically.

#### Scenario: First launch — rewarded loads after consent

- **WHEN** the app starts and the UMP consent flow has resolved (granted, denied, or skipped)
- **THEN** `AdsService` invokes `MobileAds.shared.start` and then preloads a rewarded ad in parallel with the interstitial; `rewardedReady` flips to `true` once the load completes

#### Scenario: Preload fails

- **WHEN** the rewarded ad load throws (network, no fill, etc.)
- **THEN** `rewardedReady` stays `false`, an error is logged, and the next rewarded preload is attempted on the next bootstrap or after the next dismissal

### Requirement: A "Continue — Watch Ad" CTA appears on the max-mistakes game-over screen

When `LevelGameOverView` is rendered with `failedReason == .maxMistakes`, the view SHALL render a capsule button labeled "🎬 Continue — Watch Ad" (or "✨ Continue (free)" for Remove Ads holders) above the existing "Back to Home" CTA. The button SHALL be visible only when `levelRun.hasUsedRewardedRevive == false`. For non-entitled players, the button SHALL be disabled when `AdsService.shared.rewardedReady == false`.

#### Scenario: Player runs out of lives, ad is ready

- **WHEN** the player hits game-over with `hasUsedRewardedRevive == false`, has not yet purchased Remove Ads, and `AdsService.shared.rewardedReady == true`
- **THEN** the rewarded CTA is rendered and is interactable

#### Scenario: Player runs out of lives, ad not yet loaded

- **WHEN** the same conditions but `rewardedReady == false`
- **THEN** the rewarded CTA is rendered with reduced opacity and is non-interactable; the "Back to Home" CTA below it stays usable

#### Scenario: Player has already used the revive in this run

- **WHEN** `hasUsedRewardedRevive == true` (player already revived earlier in this run)
- **THEN** the rewarded CTA is hidden entirely, leaving only "Back to Home"

### Requirement: Tapping the rewarded CTA opens the ad and grants one life on reward

When the player taps the rewarded CTA, the app SHALL flip `levelRun.hasUsedRewardedRevive = true` immediately (before presentation), then call `AdsService.shared.showRewardedAdIfReady(onReward:onSkip:)`. The `onReward` callback SHALL invoke `levelRun.grantExtraLife()` (decrementing `livesLost` by 1, guarded against negatives) and resume the run by calling `startNewLevel()` on the same level. The `onSkip` callback SHALL leave the player on `LevelGameOverView` with the rewarded CTA hidden (because the flag was already flipped).

#### Scenario: Reward earned

- **WHEN** the player watches the rewarded ad to completion and earns the reward
- **THEN** `livesLost` decrements by 1, `remainingLives` becomes 1 (assuming Hard / 1-life mode where it had hit 0), `LevelGameOverView` is dismissed, and the level is restarted from the beginning with the granted life

#### Scenario: Player closes the ad before earning the reward

- **WHEN** the player taps Continue, the rewarded ad presents, then the player taps the close button before the ad ends
- **THEN** `onSkip` runs, no life is granted, `hasUsedRewardedRevive` stays `true` (one-shot anti-abuse), and the player remains on `LevelGameOverView` with only "Back to Home" available

#### Scenario: Ad cannot be presented

- **WHEN** the player taps Continue but `AdsService` cannot find the rewarded ad or a host view controller
- **THEN** `onSkip` runs immediately, no life granted, `hasUsedRewardedRevive` stays `true` (the player chose to redeem; the redeem failed but counts), and the player can tap "Back to Home"

### Requirement: Remove Ads holders revive without watching an ad

When the player holds the Remove Ads entitlement (`StoreService.shared.hasRemoveAds == true`), `AdsService.showRewardedAdIfReady` SHALL invoke `onReward()` immediately without presenting any ad. The button label on `LevelGameOverView` SHALL read "✨ Continue (free)" instead of "🎬 Continue — Watch Ad" so the value of the entitlement is visible. The one-shot per-run cap (`hasUsedRewardedRevive`) SHALL still apply.

#### Scenario: Entitled player revives

- **WHEN** an entitled player taps "✨ Continue (free)" on `LevelGameOverView`
- **THEN** no ad is shown, `onReward` runs immediately, the life is granted, and the player resumes the level

#### Scenario: Entitled player tries to revive a second time in the same run

- **WHEN** an entitled player has already used the revive (`hasUsedRewardedRevive == true`) and reaches game-over again
- **THEN** the "Continue (free)" button is hidden — entitled and non-entitled players share the same once-per-run cap

### Requirement: A new run resets the revive availability

When the player starts a new run via `LevelRun.startRun(...)` or the run is otherwise reset via `resetRunStats()`, `hasUsedRewardedRevive` SHALL be reset to `false`. The next game-over in the new run SHALL again surface the "Continue" CTA.

#### Scenario: Back-to-Home after a run ends, then new run starts

- **WHEN** the player taps "Back to Home" after game-over (whether they used the revive or not), then starts a fresh run from the home screen
- **THEN** `hasUsedRewardedRevive == false` at the start of the new run, and the rewarded CTA is available again on the next max-mistake game-over

