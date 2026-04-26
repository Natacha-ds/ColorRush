## Why

`LevelGameView.swift` has 10 `DispatchQueue.main.asyncAfter` call sites that schedule deferred closures. Most of them mutate gameplay state (start a new round, dismiss the intro, activate the round, reset animation flags) yet none can be cancelled, and several have no internal guard either. The audit flagged this as a P0 because the rapid-input case at lines 544 and 1183 can schedule two `startNewRound()` calls that both pass the existing guard, double-executing the round and saving the score twice. The class of bug also extends beyond that single hotspot: a Back tap during the 3-second level intro still mutates `levelRun` 3 seconds later, and a Back tap during the 100 ms round-activation window still flips `isGameActive = true` on a dead view.

Closing this is a prerequisite for App Store submission and for landing ad/IAP SDKs (which add view churn and reentrancy that will hit these races much more often than today's input patterns).

## What Changes

- Introduce three `@State` slots on `LevelGameView` to hold the most recently scheduled pending work for each gameplay-critical deferred path: `pendingNextRound`, `pendingIntroDismiss`, `pendingActivation` (all `DispatchWorkItem?`).
- Convert the five gameplay-state-mutating `asyncAfter` sites (lines 544, 572, 658, 698, 1183) to the pattern: cancel the current slot's work item, create a new `DispatchWorkItem` for the body, assign it to the slot, schedule it via `asyncAfter(deadline:, execute:)`. New schedules supersede pending ones, preventing double-fire.
- Cancel and clear all three slots inside `endGameSession()`, so any in-flight deferred work is neutralised when the session ends (Back tap, level transition, etc.).
- Add `guard isGameSessionActive else { return }` to the three benign-but-cheap-to-harden sites (lines 466, 471, 1221) so animation-state writes can't leak across sessions either.
- Leave the two intentional sites untouched: line 110 (post-`dismiss()` notification chain to the leaderboard, requires the post-dismiss delay) and line 1502 (`StreakAnimationView`'s self-contained fade-out, lives in a sibling view's local lifecycle).
- Player-visible behavior under the happy path is unchanged.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `level-gameplay`: ADD a requirement that gameplay-affecting deferred work (delayed `DispatchQueue` closures that mutate session state) SHALL be cancellable and SHALL be cancelled when the session ends.

## Impact

- **Code**: ~50 lines net in `LevelGameView.swift` — three new `@State` declarations, five `DispatchWorkItem` rewrites, three guard insertions, three cancel-and-nil lines in `endGameSession()`.
- **Build**: must remain green.
- **Runtime**:
  - Happy path: identical observable behavior.
  - Race-window edge cases (rapid double-tap, Back during transitions): the redundant or stale fire is now a no-op.
  - Memory: marginal — work items are released eagerly on cancellation rather than waiting for the run loop to drain them.
- **Tests**: no tests exist today.
- **Migration**: none.
