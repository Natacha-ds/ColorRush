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

