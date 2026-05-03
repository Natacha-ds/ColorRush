## ADDED Requirements

### Requirement: An interstitial ad is considered for presentation at every end-of-run event

At every end-of-run event in `LevelGameView` (in-game Back, level-failed Back to Home, level-complete Back to Home, level-game-over Back to Home, FinalWin play-harder, FinalWin see-leaderboard), the app SHALL invoke `AdsService.showInterstitialIfReady(from:onDismiss:)` after the score save and run reset, and SHALL run the post-presentation continuation (the `DismissToHome` cascade) only inside the `onDismiss` callback.

#### Scenario: A normal end-of-run with the ad eligible

- **WHEN** an end-of-run event fires and the frequency counter has reached the cap
- **THEN** the interstitial ad is presented; on dismissal, the `onDismiss` callback runs and the `DismissToHome` notification is posted

#### Scenario: A normal end-of-run with the cap not yet reached

- **WHEN** an end-of-run event fires but the frequency counter is below the cap
- **THEN** no ad is presented, the `onDismiss` callback runs immediately, and the `DismissToHome` notification is posted

### Requirement: Interstitial frequency is capped

The interstitial ad SHALL be presented at most once every three end-of-run events. The counter SHALL be in-memory only and SHALL reset to zero on app launch.

#### Scenario: Three end-of-run events trigger one ad

- **WHEN** the player completes three end-of-run events in a single launch
- **THEN** an interstitial ad is presented exactly once (on the third event), the counter resets to zero, and the next eligible presentation is on the sixth event

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
