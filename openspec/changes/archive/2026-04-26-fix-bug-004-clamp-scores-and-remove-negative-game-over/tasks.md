## 1. Preparation

- [x] 1.1 Confirmed `addWrongAnswer()` (line 448) and `addTimeout()` (line 460) currently subtract unclamped and increment `levelPenalties` by the nominal amount
- [x] 1.2 Confirmed `resetLevelStats()` at line 392 refunds via `globalScore += levelPenalties`
- [x] 1.3 Confirmed three `.negativeScore` call sites (enum at line 9, condition at line 144, switch case at line 2192) and the negative-score block at lines 558-573

## 2. Clamp scores at the source

- [x] 2.1 `addWrongAnswer()`: `currentScore = max(0, currentScore - 10)`
- [x] 2.2 `addWrongAnswer()`: capture `oldGlobal` before clamping `globalScore`, increment `levelPenalties` by `oldGlobal - globalScore` (the actual subtracted amount)
- [x] 2.3 Removed the now-redundant `levelPenalties += 10` in `addWrongAnswer()` (folded into 2.2)
- [x] 2.4 Same shape applied to `addTimeout()` with penalty 5

## 3. Remove the negative-score game-over

- [x] 3.1 Removed the entire negative-score `if/else` block in `LevelGameView.swift` (was lines 558-573)
- [x] 3.2 Removed `case negativeScore` from `enum LevelFailureReason`
- [x] 3.3 Simplified the condition at line 144 to `if failedReason == .maxMistakes`
- [x] 3.4 Removed the `.negativeScore` branch from `lossReason` switch

## 4. Validation

- [x] 4.1 `grep -n "negativeScore\|globalScore < 0\|currentScore < 0"` returns no matches across both files (exit 1)
- [x] 4.2 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 4.3 Simulator test (level-1 forgiveness): 5 wrong taps in a row, score stays at 0, level continues, only ends on timer expiry costing 1 life (no "Score < 0")
- [x] 4.4 Simulator test (retry math): fail-and-retry produces consistent total scores
- [x] 4.5 Simulator test (leaderboard): leaderboard entry after a run with wrong taps is ≥ 0

## 5. Commit & archive

- [x] 5.1 Commit `dd75ba2 fix: clamp scores and remove negative-score game over (BUG-004, BUG-011)`
- [x] 5.2 `AUDIT_BUGS.md` status table updated (BUG-004 → ✅ Done, BUG-011 → ✅ Done as corollary) in the archive commit
- [x] 5.3 Archived via `/opsx:archive` to `2026-04-26-fix-bug-004-clamp-scores-and-remove-negative-game-over`
