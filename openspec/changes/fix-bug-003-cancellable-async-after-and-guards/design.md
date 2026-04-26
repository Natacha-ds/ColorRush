## Context

The 10 `asyncAfter` call sites in `LevelGameView.swift`, classified by what state they touch and how they should be hardened:

| Line | Where | Closure body | Category |
|---|---|---|---|
| 110 | `LevelGameOverView.onBackToHome` | Posts `SwitchToLeaderboard` notification 0.3 s after `dismiss()` | C — leave alone |
| 466 | `.onChange(of: levelRun.lastBonusEarned)` | `levelRun.lastBonusEarned = 0` after 0.1 s | B — guard only |
| 471 | Same `.onChange` | `showStreakAnimation = false` after 1.8 s | B — guard only |
| 544 | `handleTileTap` post-correct-tap | `startNewRound()` after 0.3 s | A — `DispatchWorkItem` |
| 572 | `startLevel()` | `dismissLevelIntroAndStart()` after 3.0 s | A — `DispatchWorkItem` |
| 658 | `startNewRound` setup | `isGameActive = true` after 0.1 s | A — `DispatchWorkItem` |
| 698 | Non-punitive refresh | `isGameActive = true` after 0.1 s | A — `DispatchWorkItem` |
| 1183 | `handleRoundTimeout` post-penalty | `startNewRound()` after 0.3 s | A — `DispatchWorkItem` |
| 1221 | `showErrorFlash` | `showingErrorFlash = false` after 0.2 s | B — guard only |
| 1502 | `StreakAnimationView.onAppear` (child view) | Fade-out animation after 1.5 s | C — leave alone |

The bug class is "deferred gameplay work survives the session it was created for." `Timer` was already addressed in BUG-002 with internal guards. `asyncAfter` differs from `Timer` in two ways: it fires once, and there is a real cancellation API (`DispatchWorkItem.cancel()`) that prevents the closure from running at all. So for state-mutating sites the right tool is `DispatchWorkItem`, not just an internal guard.

## Goals / Non-Goals

**Goals:**
- Make every gameplay-affecting deferred closure cancellable, and cancel them on session end.
- Prevent double-fire when rapid input triggers a new schedule before the previous one runs.
- Leave UI-only deferred animations and intentional dismiss-chained notifications alone.

**Non-Goals:**
- Touch `Timer.scheduledTimer` (BUG-002 territory, already shipped).
- Refactor child views' own animation lifecycles (line 1502).
- Replace the dispatch-based scheduling with `Task` / Combine.

## Decisions

### One slot per logical operation, replace-on-schedule

**Decision:** declare three `@State` properties on `LevelGameView`:

```swift
@State private var pendingNextRound: DispatchWorkItem?
@State private var pendingIntroDismiss: DispatchWorkItem?
@State private var pendingActivation: DispatchWorkItem?
```

Sites 544 and 1183 both write to `pendingNextRound`; sites 658 and 698 both write to `pendingActivation`; site 572 writes to `pendingIntroDismiss`. Each new schedule cancels the slot's previous occupant and replaces it with the new work item. `endGameSession()` cancels all three and sets them to nil.

**Rationale:** the bug pattern is "one logical operation can schedule overlapping work." Using one slot per operation is the smallest mechanism that handles both single-instance overlapping (rapid double-tap → only the latest `startNewRound` runs) and view dismissal (slot cancelled in `endGameSession`).

### `DispatchWorkItem` for state-mutating sites, `guard` for UI-flag sites

**Decision:** Category A uses `DispatchWorkItem`; Category B keeps `asyncAfter` and adds `guard isGameSessionActive else { return }` inside the closure.

**Rationale:** Category B sites only flip a local UI flag (`showStreakAnimation = false`, `showingErrorFlash = false`, or zero-out an already-zero animation trigger field). They cannot double-fire harmfully and the only failure mode is "writes to a flag on a dead view," which is benign. The guard is enough; introducing a fourth `@State` slot would be over-engineered.

The guard uses `isGameSessionActive` (rather than a separate flag) because that is the canonical signal for "the session is still alive" and is set false in `endGameSession()` already. Future maintainers reading the code will see the same idiom we used in BUG-002 and BUG-001 (the `.onReceive` for background notifications).

### Close the in-round re-entrance gap in `handleTileTap`

**Decision (added during apply):** flip `isGameActive = false` immediately after the entry guard in `handleTileTap`, so subsequent taps in the same round are blocked until `startNewRound()` re-enables `isGameActive` via the activation work item.

**Rationale:** the original guard at the top of `handleTileTap` reads `isGameActive`, but nothing inside the function flipped it false after a successful tap. The 300 ms `pendingNextRound` window therefore stayed wide open: rapid taps on the same correct tile each passed the guard, each called `addCorrectAnswer()`, and points cumulated. This is technically a separate bug from "non-cancellable asyncAfter", but lives in the same "rapid input race" family and is one line to fix, so we ship it here. The existing `startNewRound()` flow already sets `isGameActive = false` and re-enables it after 100 ms via `pendingActivation`, so the new line is consistent with the existing lifecycle.

### Leave Category C sites untouched

**Decision:** lines 110 and 1502 stay as plain `asyncAfter`.

- Line 110 (`SwitchToLeaderboard` notification): the *intent* of the delay is "fire after dismiss animation completes." Cancelling on dismiss is the opposite of what we want. The closure does not touch session state, only posts a notification handled by another view.
- Line 1502 (`StreakAnimationView` self-fade): lives in a child view's lifecycle. Refactoring its animation is out of scope and would cross a view boundary for no visible benefit.

Both are documented here so future readers don't "fix" them by accident.

### Helper function vs explicit pattern at each site

**Decision:** keep the cancel-build-assign-schedule pattern explicit at each site instead of extracting a helper.

**Rationale:** SwiftUI `@State` properties don't compose cleanly with `inout` parameters in helpers. Writing the four lines explicitly at each site keeps each schedule readable and makes the diff easy to review:

```swift
pendingNextRound?.cancel()
let item = DispatchWorkItem {
  if isGameSessionActive, !isLevelComplete, !isLevelFailed {
    startNewRound()
  }
}
pendingNextRound = item
DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
```

Five sites with a four-line idiom is acceptable; abstracting it into a helper would obscure the per-site guard logic for marginal savings.

## Risks / Trade-offs

- **[Risk]** A new contributor adds a sixth gameplay-affecting `asyncAfter` and forgets the cancellation pattern. → **Mitigation:** the new spec requirement documents the policy. A grep / lint rule on `asyncAfter` in `LevelGameView` could enforce it later if the surface grows.
- **[Risk]** Cancelling `pendingActivation` on `endGameSession()` racing with a legitimate level transition could prevent `isGameActive = true` from firing on the next round. → **Mitigation:** `endGameSession()` is only called when the session genuinely ends (Back tap or `handleTimeUp`), and the next `startNewRound` schedules a fresh `pendingActivation`. Inspected; no false-positive cancellation path.
- **[Trade-off]** Three new `@State` slots add a small surface to scan when reading the view. They are private and grouped at the top of the type definition.

## Migration Plan

No runtime migration. Behavior under happy path is identical; race-window edge cases now no-op or are coalesced.

**Rollback:** `git revert` the implementation commit. The three slots disappear, the original `asyncAfter` calls return, and the spec delta in `openspec/specs/level-gameplay/spec.md` can be unwound by a follow-up `MODIFIED` requirement.
