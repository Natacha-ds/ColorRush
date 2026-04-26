## ADDED Requirements

### Requirement: Deferred gameplay work is cancellable and cancelled on session end

Any deferred work scheduled inside the level-gameplay session that mutates session state (rounds, level intro, activation flags) SHALL be scheduled via a cancellable mechanism, and SHALL be cancelled when the session ends. A deferred closure that fires after the session ended SHALL be a no-op for that session's state.

#### Scenario: Rapid input does not double-schedule the next round

- **WHEN** the player taps a correct tile and, before the 300 ms scheduling delay elapses, taps a second correct tile
- **THEN** only one `startNewRound()` execution occurs (the most recently scheduled one), not two

#### Scenario: Rapid taps within a single round do not double-score

- **WHEN** the player taps a correct tile and rapidly taps any tile again before the next round materializes
- **THEN** only the first tap is scored; subsequent taps in the same round are ignored until `startNewRound()` re-enables input

#### Scenario: Back during the level intro cancels the auto-dismiss

- **WHEN** the player taps Back while the 3-second level intro is showing
- **THEN** the auto-dismiss closure does not run after dismissal and `dismissLevelIntroAndStart()` is not called on a dismissed view

#### Scenario: Back during the round-activation window cancels activation

- **WHEN** the player taps Back within 100 ms of a round being scheduled to activate
- **THEN** `isGameActive` is not set to `true` after the dismiss

#### Scenario: Animation flag writes do not leak across sessions

- **WHEN** a streak-bonus or error-flash animation has scheduled deferred state writes (e.g., resetting `showStreakAnimation` or `showingErrorFlash`) and the session ends before they fire
- **THEN** the deferred writes either do not fire or are no-ops with respect to a fresh session
