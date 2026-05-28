## ADDED Requirements

### Requirement: Share button on Game Over screen

`LevelGameOverView` SHALL render a secondary share button between the `START OVER` primary button and the `BACK TO HOME` text-link. The button SHALL combine an icon (`square.and.arrow.up`) and a localized uppercase label (`SHARE` in English, `PARTAGER` in French). Tapping it SHALL invoke the shared share pipeline (see `share-score` capability) with:
- `score` = `levelRun.globalScore + levelRun.currentScore`
- `gameType` = the run's `GameType`
- `mistakeTolerance` = the run's `MistakeTolerance`
- `source` = `.gameOver`

The button SHALL use a style consistent with the existing design system (either `.crSecondary` or an existing icon-plus-label style); no raw style literal SHALL appear in the button definition.

#### Scenario: Share button renders below START OVER
- **WHEN** `LevelGameOverView` is presented
- **THEN** a share button is visible between the `START OVER` primary CTA and the `BACK TO HOME` text-link, showing the `square.and.arrow.up` icon and the localized uppercase label

#### Scenario: Tap shares the run total score
- **WHEN** the player taps the share button on `LevelGameOverView` with `globalScore = 1390` and `currentScore = 30` in the `(.colorAndText, .hard)` run
- **THEN** the share pipeline is invoked with `score = 1420`, `gameType = .colorAndText`, `mistakeTolerance = .hard`, `source = .gameOver`, and the iOS share sheet appears

#### Scenario: Game logic untouched
- **WHEN** comparing the diff
- **THEN** all game-state methods, `levelRun` mutations, ad flows (`markReviveAttempted`, `showRewardedAdIfReady`), `onBackToHome`, and `onContinueWithExtraLife` callbacks are not modified
