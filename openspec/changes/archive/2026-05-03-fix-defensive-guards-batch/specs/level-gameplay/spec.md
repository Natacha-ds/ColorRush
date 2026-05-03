## ADDED Requirements

### Requirement: Defensive guards against pathological inputs and edge cases

The level-gameplay session and its supporting services SHALL guard against pathological inputs and edge cases — rapid input on retry, missing level configuration, corrupted persistence, and rapid haptic requests — without crashing, freezing, or producing silently-incorrect state.

#### Scenario: Haptic feedback fires reliably on rapid taps

- **WHEN** the player taps in quick succession (multiple taps within ~100 ms)
- **THEN** each tap produces a haptic impact (no feedback is dropped because of generator initialisation overhead)

#### Scenario: Corrupted leaderboard JSON does not silently disappear

- **WHEN** `LeaderboardStore.loadScores(forKey:)` reads `UserDefaults` data that fails to decode as `[ScoreEntry]`
- **THEN** the failure is logged with the offending key and the underlying error, and the function returns an empty array (the previously silent failure mode is preserved as a safe fallback, but it is no longer silent)

#### Scenario: Rapid retry tap does not double-reset level state

- **WHEN** the player rapidly taps "Try Again" on the level-failed screen, within the transition window
- **THEN** `startNewLevel()` performs the reset exactly once; subsequent calls in the same window are no-ops because both `isLevelFailed` and `isLevelComplete` have flipped false

#### Scenario: handleTimeUp with no current level config fails the level safely

- **WHEN** `handleTimeUp()` is invoked but `levelRun.currentLevelConfig` is unexpectedly nil
- **THEN** the view marks the level failed with `failedReason = .insufficientScore` and routes the player into the existing failure UI, instead of returning silently and leaving the view frozen
