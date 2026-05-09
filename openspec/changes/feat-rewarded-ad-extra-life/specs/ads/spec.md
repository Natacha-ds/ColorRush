## ADDED Requirements

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
