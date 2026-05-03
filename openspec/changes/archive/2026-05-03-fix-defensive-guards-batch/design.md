## Context

Five remaining defensive-hardening items from the audit, each small enough that bundling them avoids OpenSpec overhead disproportionate to the work. They share the theme "guard against pathological inputs / edge cases", which fits a single umbrella requirement on the existing `level-gameplay` capability.

The four code-touching items live in three files:

- `HapticsService.swift` (BUG-013): per-call `UIImpactFeedbackGenerator` instantiation.
- `LeaderboardStore.swift` (BUG-015): silent `try?` decode in `loadScores(forKey:)`.
- `LevelGameView.swift` `startNewLevel()` (BUG-019): no re-entrance guard.
- `LevelGameView.swift` `handleTimeUp()` (BUG-020): bare `return` on a missing level config.

The fifth item (BUG-016) is closed without a code change: the audit's hypothesis didn't survive code review.

## Goals / Non-Goals

**Goals:**
- Land each fix as the smallest possible diff (one-to-three lines apiece).
- Surface previously-silent failure modes (leaderboard decode, missing level config) without changing happy-path behavior.
- Document why BUG-016 is being closed without code so the audit doesn't get re-litigated.

**Non-Goals:**
- Refactor `HapticsService` into an actor or add throttling/debounce; reuse-the-instance is enough.
- Add full crash reporting / structured logging in `LeaderboardStore`; a `print` is enough at this stage.
- Add UI-level disable on the "Try Again" button; the state-flag guard covers the same case with no UI work.
- Introduce real configuration validation in `handleTimeUp`; the defensive failure is the pragmatic floor.

## Decisions

### Bundle four small fixes plus one no-op into a single change

**Decision:** ship BUG-013, BUG-015, BUG-019, BUG-020 (code) and BUG-016 (doc-only close) together in `fix-defensive-guards-batch`.

**Rationale:** every other ColorRush change has been one-bug-one-spec, but these five are too small to deserve separate proposal/design/specs/tasks artifacts each. Grouping them keeps the spec history readable (one umbrella requirement with five scenarios) and reduces five archive commits to one.

### `HapticsService`: shared generators, no debounce

**Decision:** hold `lightGenerator` and `heavyGenerator` as `private let` properties on `HapticsService`. Each call to `lightImpact()` / `heavyImpact()` invokes `impactOccurred()` on the shared instance.

**Rationale:** the audit suggested both reuse and a 50 ms debounce. The reuse is the actual fix — `UIImpactFeedbackGenerator.impactOccurred()` is already cheap on a live instance, and Apple recommends keeping the generator alive between calls (`prepare()` semantics). A debounce would mask the fix and is not needed at the user's tap rate.

### `LeaderboardStore`: log-and-default on decode failure

**Decision:** in `loadScores(forKey:)`, split the existing `guard ... try?` into:
1. `guard let data = userDefaults.data(forKey: key) else { return [] }` — handles the "no data yet" case (first launch) without logging.
2. `do { let scores = try JSONDecoder().decode(...); return ... } catch { print("Leaderboard decode failed for key '\(key)': \(error)"); return [] }` — handles corruption visibly.

**Rationale:** the "no data" case is normal and shouldn't log. Only an actual decode failure should surface. Returning `[]` on corruption is the same fail-safe behavior we have today; we just stop hiding the cause. Critical hardening before any IAP state lands in UserDefaults next to leaderboard data.

### `LevelGameView.startNewLevel()`: state-flag re-entrance guard

**Decision:** prepend `guard isLevelFailed || isLevelComplete else { return }` at the top of `startNewLevel()`.

**Rationale:** `startNewLevel()` is only meaningful when the previous round ended (failure or completion). Once it runs, both flags flip false. A second rapid call therefore hits the guard and no-ops. Cheaper than a separate `isStartingNewLevel` flag (which would itself need a reset path) and cleaner than wrapping the Try Again button in a SwiftUI `.disabled` modifier (which fights with view re-renders during the transition).

### `LevelGameView.handleTimeUp()`: defensive failure on nil config

**Decision:** turn the bare `guard let levelConfig = ... else { return }` into a guard whose `else` branch sets `isLevelFailed = true; failedReason = .insufficientScore` before returning.

**Rationale:** `handleTimeUp` is called when the level timer expires. If `currentLevelConfig` is nil at that point, something went wrong upstream (the user is in an inconsistent state), but the view should not silently freeze with no path to recovery. Marking the level failed routes the player into the existing failure UI (Try Again / Back), which is the gentlest possible "something went wrong" recovery.

### Close BUG-016 without a code change

**Decision:** document the close rationale in this proposal and update `AUDIT_BUGS.md` post-merge.

**Rationale:** the audit's "1-2 second freeze in `buildValidGrid()`" claim was conjecture, not observed. Inspection shows:
- `maxAttempts = 20`, each iteration touches 4-element arrays — measured in microseconds.
- The fallback path at the end of `buildValidGrid` always returns a valid grid; no infinite loop possible.

Adding a wall-clock timeout to a function that already terminates in microseconds is theatre. Closing as "no actionable fix; existing `maxAttempts` + deterministic fallback already cover the concern."

## Risks / Trade-offs

- **[Risk]** A future contributor adds a sixth defensive guard and accidentally bypasses the umbrella requirement when writing their own delta. → **Mitigation:** the umbrella requirement explicitly mentions the "guard against pathological inputs" theme; if a new edge case warrants a guard, it can either land as a new scenario under this requirement or as a new requirement next to it.
- **[Risk]** The `print()` in `LeaderboardStore` ends up in console logs in Release builds. → **Mitigation:** acceptable for a side-project pre-IAP. If needed, a future change can wrap it in `#if DEBUG` or pipe it through an `os_log` adapter.
- **[Trade-off]** The `startNewLevel` guard reads `isLevelFailed || isLevelComplete`, both of which are SwiftUI `@State`. SwiftUI guarantees they read the latest published value on the main thread, so the guard is reliable. If the function ever moves off the main thread, the guard would need re-evaluation — explicitly out of scope today.

## Migration Plan

No runtime migration. All four code changes are local hardening with no observable happy-path effect.

**Rollback:** `git revert` the implementation commit. The four code edits revert; the umbrella requirement in `openspec/specs/level-gameplay/spec.md` can be unwound by a follow-up `MODIFIED` requirement if needed.
