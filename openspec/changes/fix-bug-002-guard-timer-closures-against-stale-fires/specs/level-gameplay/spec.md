## ADDED Requirements

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
