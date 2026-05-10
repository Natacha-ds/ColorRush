# level-result-screens Specification

## Purpose
TBD - created by archiving change level-result-screens-redesign. Update Purpose after archive.
## Requirements
### Requirement: Shared result layout

Both `LevelCompleteView` (success — Frame 7) and `LevelFailedView` (failed — Frame 6) SHALL render the same structural layout, on a black background: a top row with TOTAL SCORE label and number on the left and `CRHeartsPill` on the right; a centered icon and `.crDisplay` headline; a small subtitle; a horizontal tone-coloured divider; a YOUR SCORE card with the level score and "OF NNN" target; a horizontal row of three `CRStatBadge`s (HITS / MISSES / STREAK); a primary CTA; a small uppercase "HOME" text-link below.

#### Scenario: Success screen layout
- **WHEN** the player completes a level (`isLevelComplete == true`)
- **THEN** `LevelCompleteView` renders the layout above with: lightning-bolt icon tinted `Theme.Colors.success`, "AMAZING" headline, "LEVEL XX - SUCCEED" subtitle, green divider, "NEXT LEVEL" primary CTA wired to `onNextLevel`

#### Scenario: Failed screen layout
- **WHEN** the player fails a level but the run continues (`isLevelFailed == true` and lives remain)
- **THEN** `LevelFailedView` renders the layout above with: skull icon tinted `Theme.Colors.warning`, "TOO SLOW" headline, "LEVEL XX - FAILED" subtitle, orange divider, "TRY AGAIN" primary CTA (with refresh icon) wired to `onRetry`

### Requirement: Top row data sources

The TOTAL SCORE number SHALL display `levelRun.globalScore + levelRun.levelPositivePoints` (the cumulative run score including the current level's positive points). The `CRHeartsPill` SHALL show `remaining: levelRun.remainingLives` over `total: levelRun.mistakeTolerance.totalLives`.

#### Scenario: Total score reflects cumulative run
- **WHEN** the player has earned 80 globalScore in previous levels and 30 levelPositivePoints in the current level
- **THEN** the TOTAL SCORE row shows "110"

#### Scenario: Hearts pill reflects remaining lives
- **WHEN** the run has 5 total lives and the player has lost 2 (`remainingLives == 3`)
- **THEN** the hearts pill shows 3 filled hearts followed by 2 dimmed hearts and the count "3"

### Requirement: YOUR SCORE card

The YOUR SCORE card SHALL display the level's current score (`levelRun.getCurrentLevelScore()`) in a large hero font and the level's required score (`levelRun.getRequiredScore()`) labeled "OF NNN" below. The card SHALL render on a `Theme.Colors.surface` rounded background.

#### Scenario: Successful run shows score over target
- **WHEN** the player completes a level with a score of 260 against a required 250
- **THEN** the YOUR SCORE card shows "260" big and "OF 250" small

#### Scenario: Failed run shows partial score
- **WHEN** the player fails a level with a score of 95 against a required 250
- **THEN** the YOUR SCORE card shows "95" big and "OF 250" small

### Requirement: Stats trio always shown

The HITS / MISSES / STREAK row SHALL always render all three `CRStatBadge`s, with values formatted with explicit sign:
- HITS: `+\(levelRun.levelBasePoints)` (or `0` if zero), tone `success`
- MISSES: `-\(levelRun.levelWrongTaps * 10)` (or `0` if zero), tone `warning`
- STREAK: `+\(levelRun.levelStreakBonuses)` (or `0` if zero), tone `info`

The v1 conditional flags `shouldShowMissed` and `shouldShowBonus` SHALL NOT gate visibility — all three badges render on every level result.

#### Scenario: Successful run with streak
- **WHEN** the player has `levelBasePoints == 240`, `levelWrongTaps == 0`, `levelStreakBonuses == 20`
- **THEN** the stat row shows HITS "+240", MISSES "0", STREAK "+20" with the tones above

#### Scenario: Failed run with mistakes
- **WHEN** the player has `levelBasePoints == 110`, `levelWrongTaps == 3`, `levelStreakBonuses == 0`
- **THEN** the stat row shows HITS "+110", MISSES "-30", STREAK "0"

### Requirement: Primary CTA preserves v1 behavior

The primary CTA on each screen SHALL invoke the existing closure passed in by `LevelGameView`:
- Success → `onNextLevel` (advances to the next level via the existing `startNewLevel()` flow)
- Failed → `onRetry` (retries the same level via the existing retry flow)

#### Scenario: NEXT LEVEL tap
- **WHEN** the player taps "NEXT LEVEL" on the success screen
- **THEN** the existing `onNextLevel` closure runs, the screen dismisses, and the next level intro modal appears

#### Scenario: TRY AGAIN tap
- **WHEN** the player taps "TRY AGAIN" on the failed screen
- **THEN** the existing `onRetry` closure runs, the screen dismisses, and the same level's intro modal appears

### Requirement: HOME link

Below the primary CTA, a small uppercase "HOME" text-link SHALL be rendered, calling the existing `onBackToHome` closure when tapped.

#### Scenario: HOME tap
- **WHEN** the player taps "HOME" on either result screen
- **THEN** the existing `onBackToHome` closure runs (which posts `DismissToHome` and surfaces the Home tab)

### Requirement: Visual fidelity to design system

Every visual constant on both result views SHALL come from the design-system primitives. Hex literals (e.g., the v1 `#F5F0FF`, `#FFF6DA`, `#F9E5D0`), hard-coded font names, raw point spacing, gradient backgrounds, emoji used as visual icons (medals, hearts, fire), and `Image("Heart")` SHALL NOT appear in the redesigned bodies of `LevelCompleteView` and `LevelFailedView`.

#### Scenario: No raw style literal in result views
- **WHEN** auditing `LevelCompleteView.body` and `LevelFailedView.body` after this change
- **THEN** every color comes from `Theme.Colors.*`, every font from `Font.cr*`, every spacing/radius from `Theme.Spacing.*` / `Theme.Radius.*`, and no `Image("Heart")` / `Image("Bomb")` / medal emoji is rendered

#### Scenario: Game logic untouched
- **WHEN** comparing the diff
- **THEN** all game-state methods (`isLevelComplete` / `isLevelFailed` transitions, `levelComplete()`, `failedReason`, `startNewLevel`, score and stat computation, ad presentation, leaderboard submission) are NOT modified; `LevelSystemModels.swift`, `Tile.swift`, `RulesView.swift`, `FinalWinView`, and the run-ending game-over view are unchanged

