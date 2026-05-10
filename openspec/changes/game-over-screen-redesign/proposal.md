## Why

`LevelGameOverView` is the screen the player sees when their run ends because they've run out of lives — the last surface still on v1 light styling. Frame 8 redesigns it with a darker, more dramatic look (red wash, prominent "GAME OVER", explicit ad-card affordances) and is the final piece of the redesign sweep. Migrating it closes the visual loop: every screen the player encounters during a normal run is now consistent.

## What Changes

- Rebuild `LevelGameOverView` (line ~2213 of `LevelGameView.swift`) using design-system primitives, on a dark background tinted with `Theme.Gradient.gameOverWash` (the radial dark-red wash already declared in the design system).
- New layout per Frame 8: dimmed empty `CRHeartsPill` top-right; big "GAME OVER" italic headline tinted `Theme.Colors.danger`; "NO LIVES LEFT" subtitle with a horizontal red divider; YOUR TOTAL SCORE label + big white score number in a `Theme.Colors.surface` card; "DON'T STOP NOW" headline + "watch an ad, get back in" subtitle; two ad cards stacked (+1 LIFE / WATCH 1 AD, +2 LIVES / WATCH 2 ADS); a primary "START OVER" button styled with `.crDanger` and the CRRetry icon prefix; small "BACK TO HOME" text link at the bottom.
- The **+1 LIFE card** preserves the existing v1 rewarded-revive behavior: gated by `levelRun.hasUsedRewardedRevive` (single-use per run), tapping calls `markReviveAttempted` then `ads.showRewardedAdIfReady` with `onContinueWithExtraLife` as the reward callback; free-for-Remove-Ads holders short-circuit straight to the reward. Once the revive has been used, the card disappears (matches v1).
- The **+2 LIVES card** is rendered for design fidelity but **disabled** in this change — the underlying capability (chain two rewarded ads + grant two lives) doesn't exist in the current game logic. The card visually shows "Soon" or a similar disabled treatment so users see the design intent without it being a broken affordance. Implementing the +2 flow is a separate follow-up change.
- The **START OVER** button preserves the v1 "Start a new game" behavior — calls the existing `onBackToHome` closure, which routes back to Home (the user can then tap PLAY to start a fresh run). Visually restyled with `.crDanger` + the CRRetry refresh icon.
- The **BACK TO HOME** text link calls the same `onBackToHome` closure (no separate reset action needed — both START OVER and BACK TO HOME exit to Home in v1; the visual hierarchy distinguishes them). If Tony wants distinct semantics later, we add a closure parameter.
- Drop v1 visual elements: light gradient background, `Image("Game-Over")` legacy emoji rasterization (replaced by the dark wash + design-system styling), `Image("Heart")` (replaced by `CRHeartsPill`), the orange-pink revive button styling, the v1 "Start a new game" purple-pink-blue gradient button.
- **No game logic changes.** Run-ending detection (`isGameOver` / `failedReason == .maxMistakes`), the routing that picks `LevelGameOverView` over `LevelFailedView`, the `markReviveAttempted` mechanics, the `ads.showRewardedAdIfReady` flow, and the `StoreService.hasRemoveAds` short-circuit all stay as-is.

## Capabilities

### New Capabilities
- `game-over-screen`: View-layer contract for the redesigned run-ending Game Over surface — what it displays, how the +1 LIFE rewarded revive integrates with the existing ad flow, how the +2 LIVES card is presented as a disabled future affordance, and the START OVER / BACK TO HOME exits.

### Modified Capabilities
<!-- None. Game-state machinery (run-ending detection, failedReason routing, rewarded ad flow) is unchanged. -->

## Impact

- **Modified**: `ColorGame/LevelGameView.swift` — only the inline `LevelGameOverView` struct (≈207 lines, lines ~2213-2419) is rewritten in place.
- **Unchanged**: `LevelSystemModels.swift`, `Tile.swift`, `RulesView.swift`, `AdsService.swift`, `StoreService.swift`, the active gameplay portion of `LevelGameView`, `LevelCompleteView`, `LevelFailedView`, `LevelIntroView`, `FinalWinView`.
- **No new dependencies**: pure SwiftUI; consumes existing `Theme.*`, `Font.cr*`, `CRHeartsPill`, `CRRetry` asset, `.crDanger` button style, and `AdsService` / `StoreService` services exactly as v1.
