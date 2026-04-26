## Why

Two compounding issues in the scoring layer make the game unfairly punitive on level 1 and let the leaderboard accept impossible scores:

1. `addWrongAnswer()` and `addTimeout()` in `LevelSystemModels.swift` deduct from `currentScore` and `globalScore` without any floor. Both can go negative.
2. `LevelGameView.swift` ends the run as soon as the relevant score crosses below zero — using `currentScore` on level 1 (since `globalScore` is still 0 there) and `globalScore` on level 2+.

The level-1 path is the worst symptom: a single wrong tap at level 1 (`-10 pts` → `currentScore = -10`) instantly fires the "Negative Score" game-over screen, regardless of the announced lives system (Easy = 5 lives, Normal = 3, Hard = 1). The user reported and confirmed this in the simulator.

Removing the negative-score game-over and clamping both scores to `≥ 0` aligns the game with its announced rules (lives are the only run-ending mechanism) and resolves the leaderboard symptom (BUG-011 in the audit) automatically — `LeaderboardStore.addScore` simply never receives a negative value anymore.

## What Changes

- Clamp `currentScore` and `globalScore` to `max(0, x - penalty)` inside `addWrongAnswer()` and `addTimeout()`.
- Track in `levelPenalties` only the **actual** amount subtracted from `globalScore` (not the nominal penalty), so the retry-restoration in `resetLevelStats()` (`globalScore += levelPenalties`) stays correct after clamping.
- Remove the negative-score game-over block in `LevelGameView.swift` (the level-1 `currentScore < 0` path and the level-2+ `globalScore < 0` path).
- Remove the `.negativeScore` case from the `LevelFailureReason` enum, plus its three remaining call sites (a condition, a switch case in `lossReason`, and the `if failedReason == .maxMistakes || .negativeScore` collapse).
- **BREAKING (gameplay)**: a wrong tap on level 1 no longer ends the run. The change is intentional, confirmed with the user.
- No persistence migration. No external API change.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `level-gameplay`: ADD two requirements that codify the new invariants — scores are clamped to non-negative, and lives are the sole run-ending mechanism.

## Impact

- **Code**:
  - `LevelSystemModels.swift`: `addWrongAnswer()` and `addTimeout()` rewritten (~10 lines touched).
  - `LevelGameView.swift`: ~20 lines removed (the negative-score block and the enum-case cleanup).
- **Build**: must remain green (`xcodebuild ... build` → `BUILD SUCCEEDED`).
- **Runtime / player behavior**:
  - Wrong taps and timeouts continue to deduct points, but the score floors at 0.
  - The "Score < 0" failure screen no longer occurs.
  - Game over is reachable only by running out of lives.
- **Leaderboard**: `globalScore` is non-negative by construction; `LeaderboardStore` cannot receive a negative score anymore. BUG-011 closes as a corollary.
- **Tests**: no tests exist today.
- **Migration**: none. Existing local `UserDefaults` entries are not affected (the leaderboard may already contain historical negative scores, but those are read-only and harmless to display).
