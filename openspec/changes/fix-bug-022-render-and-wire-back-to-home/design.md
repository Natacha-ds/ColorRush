## Context

Three exit pathways from a level-gameplay session, each with a different kind of bug, but all converging on the same symptom (lost leaderboard score):

1. **In-game Back chevron** at `LevelGameView.swift:198-218`. Current body of the button:
   ```swift
   Button(action: {
       endGameSession()
       dismiss()
   })
   ```
   No leaderboard write, no reset. Exits cleanly but throws away the run.

2. **`LevelFailedView`** (struct ~line 1848) takes `onRetry` and `onBackToHome` parameters. The parent provides a proper closure for `onBackToHome` at line 177-191 (save-then-reset-then-dismiss). But the `body` only renders the "Try Again" button. The Back-to-Home callback is wired but unreachable.

3. **`LevelCompleteView`** (struct ~line 1561) has the same UI problem (`onBackToHome` declared, never rendered). And the parent's call site at line 140-142 currently only does `dismiss()` for this callback — no save. So even if we render the button, the wiring is incomplete.

The save-then-reset-then-dismiss pattern is already canonicalised in three other places in the file (lines 87-97, 102-119, 152-167, 177-191). Two minor variants exist:
- **With `if totalScore > 0` guard** (lines 152-191): used by failure / game-over paths.
- **Without the guard** (lines 87-119): used by FinalWin paths where the player just won level 10, score is guaranteed positive.

For all three new save sites in this change, the player may have any non-negative score (including 0 if they just opened a level and immediately backed out). The `> 0` guard is the right pattern — same as failure paths.

## Goals / Non-Goals

**Goals:**
- Make every exit path save the accumulated positive score before dismissing.
- Give the player a visible Back-to-Home affordance on the failure and level-complete screens.
- Apply the existing save pattern verbatim — no new variant.

**Non-Goals:**
- Confirmation dialog / "are you sure you want to quit?" prompt — out of scope, would need product decision.
- Restyling the failure / level-complete screens beyond adding the new button.
- Touching `FinalWinView` or `LevelGameOverView` — both already have working Back-to-Home flows.
- Writing the in-game Back button to use a separate state (e.g., "in-game-exit" tracking) — same pattern as the other paths is fine.

## Decisions

### Re-use the canonical save-then-reset-then-dismiss pattern at all three new sites

**Decision:** at each of the three new save sites, write:
```swift
let totalScore = levelRun.globalScore + levelRun.levelPositivePoints
if totalScore > 0 {
    LeaderboardStore.shared.addScore(totalScore, for: levelRun.mistakeTolerance)
}
levelRun.resetRunStats()
levelRun.currentLevel = 1
levelRun.isActive = false
dismiss()
```

**Rationale:** matches the pattern already used at lines 152-167 and 177-191. Same `> 0` guard (intended to skip 0-point runs that are essentially "the player opened the level and bailed before scoring anything" — those don't deserve a leaderboard entry). Same reset sequence so the next session starts clean. No new variant means future readers don't have to wonder which save shape applies where.

### Render Back-to-Home as a secondary text button below the primary CTA

**Decision:** add a `Button(action: onBackToHome) { Text("Back to Home") }` styled with no gradient fill and a muted color (e.g., `.foregroundColor(.secondary)`), placed underneath the "Try Again" / "Next Level" buttons, with modest vertical spacing.

**Rationale:** the primary CTAs ("Try Again" / "Next Level" / "Finish Run") are heavy gradient buttons that dominate the screen. The secondary action shouldn't compete visually — players who tapped the primary CTA last time should still find it on the same spot. A subtle text button is the iOS convention for this exact "secondary alternative action" role.

### Don't add a confirmation prompt on exit

**Decision:** the in-game Back chevron stays a single-tap action; tapping it ends the run immediately (with save).

**Rationale:** adding a "Are you sure?" prompt is a product decision (tradeoff between accidental exits vs friction). Out of scope for this bug fix; can be added later as a UX polish if accidental exits become a complaint. Keeping the current behavior preserves muscle memory.

### `LevelCompleteView` Back-to-Home is not the same as Finish Run

**Decision:** keep both "Finish Run" and "Back to Home" on `LevelCompleteView` when applicable. Their semantics differ:
- "Next Level" / "Finish Run" — the primary forward action (continue to next level, or end run on level 10).
- "Back to Home" — exit the run early after the current level. Saves the cumulative score and returns.

**Rationale:** "Finish Run" is only shown when `levelRun.isCompleted` is true (level 10 path); for levels 1-9 it reads "Next Level". "Back to Home" is the *escape hatch* — different intent. Both can coexist without conflict.

## Risks / Trade-offs

- **[Risk]** A player who taps the in-game Back chevron by accident now loses their run with no warning. → **Mitigation:** previously the chevron also exited the run, just without the side benefit of saving the score. The new behavior is strictly better — no regression, just a save. If accidental exits become a real complaint, a follow-up change can add a confirmation prompt.
- **[Risk]** The new "Back to Home" button on `LevelCompleteView` could be tapped by a player who meant to advance to the next level. → **Mitigation:** different visual treatments (gradient CTA vs subtle text button) make the choice clear.
- **[Trade-off]** Three new save call sites all use the same boilerplate `> 0`-guard pattern. We could extract a helper, but the pattern is already inlined in three other places in the file; consistency wins over deduplication for now.

## Migration Plan

No runtime migration. Player-visible behavior on the happy path (primary CTAs) is unchanged.

**Rollback:** `git revert` the implementation commit. The new buttons disappear and the in-game Back chevron reverts to its previous (silent-exit) behavior. The spec delta in `openspec/specs/level-gameplay/spec.md` can be unwound by a follow-up `MODIFIED` requirement.
