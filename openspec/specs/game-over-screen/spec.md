# game-over-screen Specification

## Purpose
TBD - created by archiving change game-over-screen-redesign. Update Purpose after archive.
## Requirements
### Requirement: Game Over screen layout

The Game Over screen SHALL render, on a dark background with a centered radial dark-red wash (`Theme.Gradient.gameOverWash`), the following elements stacked vertically: a dimmed empty `CRHeartsPill` aligned top-right; a big "GAME OVER" italic display headline tinted `Theme.Colors.danger`; a "NO LIVES LEFT" subtitle with a horizontal red divider; a centered YOUR TOTAL SCORE card with the cumulative run score in hero font; a "DON'T STOP NOW" prompt + "watch an ad, get back in" subtitle; two stacked ad cards (+1 LIFE, +2 LIVES); a primary "START OVER" button at the bottom using `.crDanger`; a small "BACK TO HOME" text-link below.

#### Scenario: Default render
- **WHEN** the player runs out of lives and `LevelGameOverView` is presented
- **THEN** the screen renders the layout above with the radial dark-red wash visible behind the content, "GAME OVER" prominent, and the player's cumulative score shown in the YOUR TOTAL SCORE card

### Requirement: +1 LIFE rewarded revive preserves v1 behavior

The +1 LIFE ad card SHALL preserve the existing v1 rewarded-revive flow: it is rendered only when `levelRun.hasUsedRewardedRevive == false`; tapping it calls `levelRun.markReviveAttempted()` then `AdsService.shared.showRewardedAdIfReady(onReward:onSkip:)`; on successful reward the parent's `onContinueWithExtraLife` closure is invoked; players holding the Remove Ads entitlement (`StoreService.hasRemoveAds == true`) skip the ad and receive the life directly via the `showRewardedAdIfReady` short-circuit.

#### Scenario: First tap opens the rewarded ad
- **WHEN** `hasUsedRewardedRevive == false` and `ads.rewardedReady == true` and the player taps the +1 LIFE card
- **THEN** `markReviveAttempted()` is invoked first (so closing the ad early still consumes the revive), then `ads.showRewardedAdIfReady(onReward:onSkip:)` presents the ad

#### Scenario: Successful reward continues the run
- **WHEN** the user finishes watching the ad and the `onReward` callback fires
- **THEN** the parent's `onContinueWithExtraLife` closure is invoked; the screen dismisses and the player resumes the level with one more life

#### Scenario: Remove Ads holder skips the ad
- **WHEN** the +1 LIFE card is tapped and `StoreService.hasRemoveAds == true`
- **THEN** `showRewardedAdIfReady` short-circuits to invoke `onReward` directly without presenting an ad; the parent's `onContinueWithExtraLife` closure runs

#### Scenario: Card hidden after revive used
- **WHEN** `levelRun.hasUsedRewardedRevive == true`
- **THEN** the +1 LIFE card is no longer rendered on the screen

### Requirement: +2 LIVES card not rendered in this change

Per Tony's decision, the +2 LIVES card from Frame 8 SHALL NOT be rendered in this change. Only the +1 LIFE card is shown — the +2 ads chain capability is deferred to a separate future change with its own UX consideration (early-close handling, preload spinner, etc.). The visible layout therefore shows a single ad card centered between the prompt text and the START OVER button.

#### Scenario: +2 LIVES card not present
- **WHEN** the Game Over screen renders
- **THEN** there is no +2 LIVES card in the view hierarchy; only the +1 LIFE card (when applicable) is shown

### Requirement: START OVER preserves v1 exit behavior

The "START OVER" primary button at the bottom of the screen SHALL invoke the existing `onBackToHome` closure passed in by `LevelGameView`, exiting the run and returning the player to the Home tab. The button SHALL use the `.crDanger` button style and prefix its label with the `CRRetry` refresh icon.

#### Scenario: START OVER tap exits to Home
- **WHEN** the user taps "START OVER"
- **THEN** the existing `onBackToHome` closure runs, the screen dismisses, and the player is on the Home tab

### Requirement: BACK TO HOME text-link

A small uppercase "BACK TO HOME" text-link SHALL be rendered below the START OVER button, also calling `onBackToHome`. It SHALL render in a quieter visual weight (e.g., `.crButtonLabel` font + `Theme.Colors.textSecondary`) so the user perceives it as a secondary exit affordance.

#### Scenario: BACK TO HOME tap exits to Home
- **WHEN** the user taps "BACK TO HOME"
- **THEN** `onBackToHome` runs (identical destination to START OVER in this version)

### Requirement: Visual fidelity to design system

Every visual constant on the Game Over screen SHALL come from the design-system primitives. Hex literals, hard-coded font names, raw point spacing, light-mode gradient backgrounds, `Image("Heart")` / `Image("Game-Over")` legacy assets, and emoji used as visual icons SHALL NOT appear in the redesigned `LevelGameOverView` body.

#### Scenario: No raw style literal in the rewritten body
- **WHEN** auditing `LevelGameOverView.body` after this change
- **THEN** every color comes from `Theme.Colors.*` / `Theme.Gradient.*`, every font from `Font.cr*`, every spacing/radius from `Theme.Spacing.*` / `Theme.Radius.*`, and no `Image("Heart")` / `Image("Game-Over")` reference appears

#### Scenario: Game logic untouched
- **WHEN** comparing the diff
- **THEN** all game-state methods (run-ending detection, `failedReason == .maxMistakes` routing, `markReviveAttempted`, `showRewardedAdIfReady` flow), `LevelSystemModels.swift`, `Tile.swift`, `AdsService.swift`, `StoreService.swift`, and other gameplay-state files are not modified

