## Context

Three `Timer.scheduledTimer` call sites in `LevelGameView`, all with identical shape and identical lack of guards:

```swift
// gameTimer (initial, ~line 601)
gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    if timeRemaining > 0 {
        timeRemaining -= 0.1
    } else {
        handleTimeUp()
    }
}

// roundTimer (~line 1135)
roundTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    roundTimeRemaining -= 0.1
    if roundTimeRemaining <= 0 {
        handleRoundTimeout()
    }
}

// gameTimer (resume, ~line 1287)
gameTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    if timeRemaining > 0 {
        timeRemaining -= 0.1
    } else {
        handleTimeUp()
    }
}
```

`LevelGameView` is a SwiftUI `struct`. The closure captures `self` by value at scheduling time. The captured `self` carries property wrappers for the relevant `@State` (`timeRemaining`, `roundTimeRemaining`, `isGameSessionActive`, `isRoundTimerActive`, etc.), all of which point to external storage owned by SwiftUI and tied to the view's identity.

Existing teardown invariants:

- `.onDisappear` calls `endGameSession()`, which sets `isGameSessionActive = false` and invalidates `gameTimer`.
- `endRoundTimer()` sets `isRoundTimerActive = false` and invalidates `roundTimer`.
- `pauseTimer()` (now triggered via the `.onReceive` modifier introduced by BUG-001) invalidates both timers but leaves `isGameSessionActive` true so `resumeTimer()` can restart them.

The race window the bug exploits: a tick that has already been delivered to the run loop but not yet executed when the teardown runs. After teardown, the body still runs, mutates external `@State`, possibly calls handlers that re-enter `endGameSession`, etc.

## Goals / Non-Goals

**Goals:**
- Make every scheduled tick a no-op once the corresponding session/round is no longer active.
- Keep the change tiny and unambiguous so it's easy to verify by reading the diff.

**Non-Goals:**
- Refactor the timer system to use Combine or `TimelineView`.
- Introduce a dedicated `ObservableObject` for timer state.
- Cancel `DispatchQueue.main.asyncAfter` closures (BUG-003 territory, separate change).
- Add `[weak self]` — does not apply to a SwiftUI `struct` view.

## Decisions

### Use `@State` flag guards inside each closure

**Decision:** prepend `guard isGameSessionActive else { return }` to the two `gameTimer` closures, and `guard isRoundTimerActive else { return }` to the `roundTimer` closure.

**Rationale:** Swift does not support `[weak self]` for value types, so the closure unavoidably captures the struct. The right place to neutralize stale ticks is the closure itself, by reading a `@State` flag whose value is reliably set to `false` during teardown. SwiftUI's `@State` storage is preserved long enough to read the last value safely, so the guard works even if the underlying view has been removed from the hierarchy.

The chosen flags align with the timer's semantics:
- Game timers serve a "session" — `isGameSessionActive` flips false in `endGameSession()`
- Round timer serves a "round" — `isRoundTimerActive` flips false in `endRoundTimer()`

This keeps the guard semantically meaningful at each call site instead of using a single global flag.

### Alternatives considered

**Alt A — invalidate timers earlier and trust cancellation.**
Move `gameTimer?.invalidate()` to fire before any state changes that could cause a stale execution. Rejected: this still leaves the in-flight tick window. Once a tick has been delivered to the run loop, `invalidate()` cannot recall it.

**Alt B — wrap timer state in an `ObservableObject` and use `[weak self]`.**
Cleaner long-term. Rejected for this change because it's a significantly larger refactor than the bug needs. The minimal guard fix unblocks the App Store submission; a future change can revisit if the timer system grows more responsibilities.

**Alt C — switch to `TimelineView` or a Combine `Timer.publish`.**
SwiftUI-native and lifetime-managed by the framework. Rejected for this change: substantial rewrite of the rendering loop and risk of regressions in rate / pause behavior. Worth revisiting in a dedicated refactor change after the App Store ship, not as part of a bug fix.

## Risks / Trade-offs

- **[Risk]** A future contributor may add a fourth Timer site and forget the guard, reintroducing the bug. → **Mitigation:** the new requirement in the `level-gameplay` spec documents the policy. A grep / lint rule could enforce it later if the surface grows.

- **[Risk]** `isGameSessionActive` could be flipped false legitimately mid-session by some path other than teardown, causing the timer to wrongly stop. → **Mitigation:** auditing the codebase shows `isGameSessionActive = false` is set only in `endGameSession()` and at the top of `pauseTimer()`. `pauseTimer()` invalidates the timer right after, so the guard would only block ticks the timer wouldn't deliver anyway.

- **[Trade-off]** This is a "patch" rather than a structural fix. Acceptable given the goal (ship to App Store). The structural fix (move to ObservableObject or TimelineView) is documented in the alternatives so future work has a starting point.

## Migration Plan

No runtime migration. Behavior under the happy path is identical; race-window edge cases now no-op instead of corrupting state.

**Rollback:** `git revert` the implementation commit. The guards disappear, the spec delta in `openspec/specs/level-gameplay/spec.md` can be unwound by a follow-up `MODIFIED` requirement.
