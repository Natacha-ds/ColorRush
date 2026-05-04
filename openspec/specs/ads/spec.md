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

