## Why

`LevelGameView` schedules three repeating `Timer.scheduledTimer` callbacks (the level-wide `gameTimer` at start and on resume, plus a per-round `roundTimer`). None of the closures guards against running after the view's session has ended. `Timer` keeps its closure alive on the `RunLoop` until invalidated, so a tick that lands between the view's `.onDisappear` and the synchronous teardown work — or any other small race — mutates `@State` (`timeRemaining`, `roundTimeRemaining`, etc.) on a session that has already ended.

The audit flagged this as a possible "Unexpectedly found nil" crash. In practice the more visible risk is silent state corruption: the timer ticks below zero, the resume logic restarts on stale state, or `handleTimeUp()`/`handleRoundTimeout()` runs in a phantom session right before the view goes away. Either way, the bug becomes much more dangerous once we add ad SDKs (more view churn) and IAP transactions (more reentrancy), and it has to be closed before App Store submission.

## What Changes

- In `LevelGameView.swift`, add `guard isGameSessionActive else { return }` at the top of the two `gameTimer` closures (the initial schedule in the `startLevel()` flow and the post-background restart in `resumeTimer()`).
- Add `guard isRoundTimerActive else { return }` at the top of the `roundTimer` closure in `startRoundTimer()`.
- No change to `handleTimeUp()`, `handleRoundTimeout()`, `endGameSession()`, `endRoundTimer()`, `pauseTimer()`, or `resumeTimer()` themselves.
- No public API change. No persistence change. Player-visible behavior under the happy path is identical.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `level-gameplay`: ADD a requirement that scheduled `Timer` callbacks SHALL be inert (no-op early return) when the session or round they were created for is no longer active.

## Impact

- **Code**: three small guard additions in `LevelGameView.swift`, ~3 lines net.
- **Build**: must remain green.
- **Runtime**:
  - Happy path: no observable change.
  - Race-window edge cases (tap Back mid-tick, foreground transition mid-tick, level retry mid-tick): the stale tick is now a no-op rather than a state mutation.
- **Memory**: marginal improvement — closures may hang on the `RunLoop` slightly less, since they early-return rather than executing the body. The Timer object itself is still invalidated by the existing teardown paths.
- **Tests**: no tests exist today.
- **Migration**: none.
