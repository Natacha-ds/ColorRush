## Why

Three exit paths in `LevelGameView.swift` silently lose the player's accumulated leaderboard score:

1. **In-game Back chevron** (line ~200): the `chevron.left` button visible during active gameplay calls `endGameSession()` and `dismiss()` only — no leaderboard write. A player who exits mid-level loses everything they had earned.
2. **`LevelFailedView`** (struct ~line 1848): declares `onBackToHome` and the parent provides a proper save closure, but the `body` only renders "Try Again". The user reported being trapped on a failed Easy run with 150 points and no way to exit besides force-quit; their score never reached the leaderboard.
3. **`LevelCompleteView`** (struct ~line 1561): same problem — `onBackToHome` declared but no button rendered. On top of that, the parent's `onBackToHome` closure for this view (line 140-142) only does `dismiss()` with no save logic, so even if we render the button, it would currently silently lose the score.

Net effect: across realistic player flows, a Normal/Easy run can score 100+ points and end up with an empty leaderboard. This is a P0 product issue — the leaderboard is a primary engagement mechanic.

## What Changes

- **In-game Back button** (line ~200): wrap the existing `endGameSession(); dismiss()` body with the canonical save-then-reset-then-dismiss pattern (compute `totalScore = levelRun.globalScore + levelRun.levelPositivePoints`, save to leaderboard if `> 0`, `levelRun.resetRunStats()`, `levelRun.currentLevel = 1`, `levelRun.isActive = false`, then `dismiss()`).
- **`LevelFailedView`** (~line 1848): render a "Back to Home" secondary button in the `body`, below the existing "Try Again" CTA. Style as a subtle text-style button so it doesn't compete visually with the primary action. Wire to the existing `onBackToHome` parameter.
- **`LevelCompleteView`** (~line 1561): same — render a "Back to Home" secondary button below the "Next Level" / "Finish Run" CTA, wired to `onBackToHome`.
- **`LevelGameView`'s `LevelCompleteView` call site** (line 140-142): replace the bare `dismiss()` with the same save-then-reset-then-dismiss pattern as the other call sites, so the newly-rendered button actually saves the score.
- No change to scoring math, level transitions, or any other gameplay element.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `level-gameplay`: ADD a requirement that every player-initiated exit path (in-game Back, level-failed Back to Home, level-complete Back to Home) saves the accumulated positive score to the leaderboard before dismissing the run.

## Impact

- **Code**: ~30 lines net across `LevelGameView.swift`. No other files touched.
- **Build**: must remain green.
- **Runtime / player behavior**:
  - All three exit paths now save the run's accumulated positive score (clamped ≥ 0 thanks to BUG-004) to the leaderboard under the appropriate `MistakeTolerance`.
  - Failed-level and level-complete screens now show a secondary "Back to Home" button next to the primary CTA, so the player is no longer trapped in a Try Again / Next Level loop.
  - The in-game Back chevron continues to dismiss instantly (no extra confirmation), but now leaves a clean leaderboard entry behind.
- **Persistence**: no schema change.
- **Tests**: no tests exist today.
- **Migration**: none.
