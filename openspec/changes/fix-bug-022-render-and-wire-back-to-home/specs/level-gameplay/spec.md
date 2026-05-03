## ADDED Requirements

### Requirement: Every player-initiated exit path saves the accumulated score

Every player-initiated path that exits a level-gameplay run before its natural end (in-game Back chevron, "Back to Home" on the level-failed screen, "Back to Home" on the level-complete screen) SHALL save the run's accumulated positive score (`globalScore + levelPositivePoints`) to `LeaderboardStore` under the run's `mistakeTolerance` if the score is greater than zero, then reset the run state and dismiss the view.

#### Scenario: In-game Back chevron mid-level saves the run's accumulated score

- **WHEN** the player is mid-level with `globalScore + levelPositivePoints == 150` and taps the in-game Back chevron at the top of the screen
- **THEN** the run's score (150) is saved to the leaderboard under the played `mistakeTolerance`, the run state is reset, and the view dismisses

#### Scenario: Level-failed screen exposes a Back to Home button that saves

- **WHEN** the player has just failed a level with insufficient score and is on `LevelFailedView`
- **THEN** a "Back to Home" secondary button is visible next to the "Try Again" primary button, and tapping it saves the accumulated score (if > 0), resets the run, and dismisses the view

#### Scenario: Level-complete screen exposes a Back to Home button that saves

- **WHEN** the player has just completed a level (1-9) and is on `LevelCompleteView`
- **THEN** a "Back to Home" secondary button is visible next to the "Next Level" primary button, and tapping it saves the cumulative score (if > 0), resets the run, and dismisses the view

#### Scenario: Back to Home actually returns to the Home tab, not the level selector

- **WHEN** any "Back to Home" exit fires (in-game chevron, level-failed, level-complete, game-over)
- **THEN** the player lands on the Home tab of the tab bar, with both the `LevelGameView` and the `LevelSystemSelectionView` dismissed (achieved by posting a `DismissToHome` notification that `HomeView` listens to)
