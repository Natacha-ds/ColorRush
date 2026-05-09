# level-gameplay Specification

## Purpose

The `level-gameplay` capability covers the rendering and orchestration of a level-based game session — from the moment the player launches a level to its completion or failure. It enforces that exactly one canonical view powers in-game rendering, leaving no room for legacy or alternative game views in the shipped target.
## Requirements
### Requirement: Single canonical level-gameplay view

The application SHALL render any level-based game session exclusively through the `LevelGameView` view. No other game view (legacy or alternative) shall coexist in the compiled `ColorGame` target.

#### Scenario: Starting a game from the selection screen

- **WHEN** the player picks a mode and difficulty in `LevelSystemSelectionView` and taps "Start"
- **THEN** the game session opens in an instance of `LevelGameView` (and no other game view)

#### Scenario: Source code audit

- **WHEN** a developer searches the `ColorGame` target for game-view definitions
- **THEN** only `LevelGameView` is defined; no legacy `struct GameView: View` remains in the module

### Requirement: Level-gameplay session is decoupled from user-tunable customization

The level-gameplay session SHALL run from a fixed, code-defined level configuration and SHALL NOT depend on any user-tunable customization store, persisted preference, or external tuning model for its in-game behavior.

#### Scenario: No customization store on the runtime path

- **WHEN** a developer audits the dependencies of `LevelGameView` and its supporting types
- **THEN** no reference to a `CustomizationStore`, `GameCustomization`, or equivalent user-tunable persistence layer exists on the active runtime path

#### Scenario: Fresh install with no persisted state

- **WHEN** a player launches the app for the first time, with no `UserDefaults` entries set
- **THEN** they can start and complete a level without any customization-related code path executing

### Requirement: Level-gameplay session releases all system observers on dismiss

The level-gameplay session SHALL register any system notifications (in particular app background/foreground events) using a mechanism whose lifetime is bound to the SwiftUI view's lifetime, and SHALL NOT leak observers across sessions. After the view is dismissed, no observer registered by that session shall remain active in `NotificationCenter`.

#### Scenario: Single session, single registration

- **WHEN** a player starts a level and the `LevelGameView` materializes
- **THEN** at most one observer per registered notification name is active for that view instance

#### Scenario: Repeated sessions do not accumulate observers

- **WHEN** a player starts and exits five level sessions in a row
- **THEN** at any point during or after, the number of active observers registered by `LevelGameView` is bounded by the number of currently-mounted instances (typically one), independent of how many sessions have been played

#### Scenario: Background event fires the timer pause exactly once

- **WHEN** the app moves to the background while a single `LevelGameView` is mounted
- **THEN** the game timer is paused exactly once, regardless of how many prior sessions have been played in the same launch

### Requirement: Scores never go negative

`currentScore` and `globalScore` SHALL be clamped to a non-negative range. Any operation that would deduct points (wrong tap, timeout) SHALL floor the resulting value at zero rather than producing a negative number.

#### Scenario: Wrong tap from a low score does not produce a negative value

- **WHEN** the player taps an incorrect tile while their `currentScore` is 5 and the wrong-tap penalty is 10
- **THEN** their `currentScore` becomes 0 (not -5)

#### Scenario: Wrong tap from zero stays at zero

- **WHEN** the player taps an incorrect tile while their `currentScore` is already 0
- **THEN** their `currentScore` remains 0 and the level continues

#### Scenario: Retry refund is consistent with clamping

- **WHEN** the player accumulates penalties whose nominal sum exceeds their `globalScore`, fails the level, and retries
- **THEN** the retry refund applied to `globalScore` equals exactly what was actually subtracted (not the nominal sum), so the player cannot gain points by failing

### Requirement: Lives are the only run-ending mechanism

The level-gameplay session SHALL end a run only when the player runs out of lives. Score-based game-over conditions SHALL NOT exist; in particular, no negative-score check shall fail the run.

#### Scenario: Aggressive wrong tapping at level 1 does not end the run

- **WHEN** the player makes five wrong taps in a row at level 1 without ever reaching `requiredScore`
- **THEN** the level fails by `insufficientScore` at the end of its timer (costing one life), not by `negativeScore` mid-round

#### Scenario: A still-alive run never ends mid-level due to scoring

- **WHEN** the player has at least one life remaining
- **THEN** the run cannot transition to game over until either the lives counter is exhausted or, in the no-lives state, the next failed-level event occurs

### Requirement: Scheduled timer callbacks are inert when their session ends

Every scheduled `Timer` callback in the level-gameplay session SHALL early-return without performing any state mutation when the session or round it serves is no longer active. A scheduled tick that lands after teardown SHALL be a no-op.

#### Scenario: Stale game-timer tick after view dismissal

- **WHEN** the player dismisses the level mid-tick (a `gameTimer` closure has been delivered to the run loop but not yet executed) and `endGameSession()` has set `isGameSessionActive` to `false`
- **THEN** the closure exits at its guard and does not modify `timeRemaining` or call `handleTimeUp()`

#### Scenario: Stale round-timer tick after `endRoundTimer()`

- **WHEN** a `roundTimer` closure is delivered to the run loop after `endRoundTimer()` has set `isRoundTimerActive` to `false`
- **THEN** the closure exits at its guard and does not modify `roundTimeRemaining` or call `handleRoundTimeout()`

#### Scenario: Active session is unaffected

- **WHEN** the player is mid-level with the session active and a normal tick fires
- **THEN** the guard passes and the timer body executes as before, decrementing the appropriate remaining-time state and triggering its expiry handler when applicable

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

### Requirement: Non-punitive refresh re-speaks the announced color

On levels with the non-punitive refresh mechanic (levels 9-10), every refresh of the tile grid SHALL re-speak the current announced color via `SpeechService.speak(_:)`, so the audio cue stays in sync with the visual board.

#### Scenario: Idle on level 9 — color is re-spoken on each refresh

- **WHEN** the player is on level 9 and does not tap, allowing the 1-second round timer to expire repeatedly
- **THEN** the announced color is audibly re-spoken on each refresh, with no audible overlap (each new playback pre-empts the previous)

#### Scenario: Tap mid-refresh — round transitions cleanly

- **WHEN** the player taps a correct tile on level 9 right after a refresh has just fired
- **THEN** the next round's announce plays cleanly (the in-flight refresh announce is pre-empted by `SpeechService` before the new round announce starts)

### Requirement: Streak-bonus animation shows the streak count, not the bonus delta

The streak-bonus animation overlay SHALL display the consecutive-correct-answer count reached at the milestone (e.g., "10 in a row!"), not the bonus point delta. The score itself SHALL continue to be incremented by the bonus at the moment of the milestone, but the on-screen label SHALL NOT imply that the displayed number is a separate, yet-to-be-added point award.

#### Scenario: Color Only — milestone at 10 consecutive correct

- **WHEN** the player reaches 10 consecutive correct taps in Color Only mode
- **THEN** the animation overlay reads "🔥 10 in a row!" (and the score has already been incremented by the streak bonus)

#### Scenario: Color+Text — milestone at 5 consecutive correct

- **WHEN** the player reaches 5 consecutive correct taps in Color+Text mode
- **THEN** the animation overlay reads "🔥 5 in a row!"

#### Scenario: Wrong tap resets the streak

- **WHEN** the player has built a streak below the next milestone and then taps incorrectly
- **THEN** `currentStreak` resets to zero and no animation fires until the next milestone is reached on a fresh streak

### Requirement: Resume from interruption re-anchors the audio cue

When the level-gameplay session resumes after a pause-causing interruption (backgrounding, phone call, Control Center, app switch, etc.) and the level timer has not expired during the interruption, the application SHALL re-speak the current announced color via `SpeechService.speak(_:)`, so the player has an immediate audio anchor on the active round.

#### Scenario: Resume from a backgrounded session re-speaks the color

- **WHEN** the player is mid-round, the announced color is "Red", they background the app for a few seconds, and they return
- **THEN** "Red" is re-spoken as the round resumes (in addition to the existing time-deduction)

#### Scenario: Resume after the level timer has already expired does not re-speak

- **WHEN** the player backgrounds the app for longer than the remaining level time, so resuming triggers `handleTimeUp()` immediately
- **THEN** no re-speak occurs (no audio is played for a level that ended during the interruption)

#### Scenario: Normal round transition is unchanged

- **WHEN** the player taps a correct tile within an uninterrupted round and the next round starts
- **THEN** the new round announces its new color exactly once (the resume re-speak does not fire on normal round transitions)

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

### Requirement: Color voice audio is spoken in the player's locale

When `SpeechService.speak(_:)` plays the announced-color audio (initial round, resume from interruption, or non-punitive refresh on levels 9-10), the audio file resolved by the bundle SHALL match the player's current locale when one is supported. For French-locale players the mp3 SHALL pronounce the French color name (e.g., "rouge"); for English-locale players it SHALL pronounce the English name (e.g., "red"); for any other locale the system SHALL fall back to the English file.

#### Scenario: French-locale gameplay

- **WHEN** the player runs the app on a French-locale device and a round announces the color red
- **THEN** the audio cue plays the French pronunciation "rouge" rather than the English "red"

#### Scenario: English-locale gameplay

- **WHEN** the player runs the app on an English-locale device and a round announces the color red
- **THEN** the audio cue plays the English pronunciation "red"

#### Scenario: Unsupported-locale fallback

- **WHEN** the player runs the app on a German or Spanish locale device (not yet localized)
- **THEN** the audio cue falls back to the English mp3 with no error, no silent gap, and the gameplay flow continues normally

