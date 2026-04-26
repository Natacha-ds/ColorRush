## 1. Preparation

- [x] 1.1 Confirmed the 10 `asyncAfter` sites and their categorization (5 Category A, 3 Category B, 2 Category C)
- [x] 1.2 Confirmed `endGameSession()` is the canonical session-end teardown path

## 2. Add the three pending-work slots

- [x] 2.1 Declared `@State private var pendingNextRound: DispatchWorkItem?` on `LevelGameView`
- [x] 2.2 Declared `@State private var pendingIntroDismiss: DispatchWorkItem?`
- [x] 2.3 Declared `@State private var pendingActivation: DispatchWorkItem?`
- [x] 2.4 Cancel + nil all three slots inside `endGameSession()`

## 3. Convert Category A sites to `DispatchWorkItem`

- [x] 3.1 Site at handleTileTap → `pendingNextRound` (cancel-build-assign-schedule pattern)
- [x] 3.2 Site at handleRoundTimeout → `pendingNextRound` (same slot, prevents double-fire)
- [x] 3.3 Site at startLevel intro auto-dismiss → `pendingIntroDismiss`
- [x] 3.4 Site at startNewRound activation → `pendingActivation`
- [x] 3.5 Site at refreshBoardOnly activation → `pendingActivation` (same slot)

## 3b. Close the in-round re-entrance gap (discovered during apply)

- [x] 3b.1 In `handleTileTap`, set `isGameActive = false` immediately after the entry guard so rapid taps on the same correct tile cannot double-score before the next round materializes

## 4. Add guards to Category B sites

- [x] 4.1 `.onChange(of: levelRun.lastBonusEarned)` reset closure: prepended `guard isGameSessionActive else { return }`
- [x] 4.2 Same `.onChange` show-streak-animation closure: prepended same guard
- [x] 4.3 `showErrorFlash` reset closure: prepended same guard

## 5. Validation

- [x] 5.1 `grep -n "asyncAfter" ColorGame/LevelGameView.swift` shows: 5 `execute: item` (Category A converted), 3 plain `asyncAfter` with guards (Category B), 2 plain `asyncAfter` left intentional (Category C — leaderboard chain at line 115 and `StreakAnimationView` self-fade at line 1532)
- [x] 5.2 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 5.3 Simulator happy path: rounds advance correctly, level intro auto-dismisses at 3 s, end-of-level transitions cleanly
- [x] 5.4 Simulator stress (Back during gameplay): no crash, no startNewRound after dismissal, no isGameActive mutation
- [x] 5.5 Simulator stress (Back during intro): no level start in background after Back
- [x] 5.6 Simulator stress (rapid round retry): next round starts cleanly without zombie pending work
- [x] 5.7 Simulator regression (BUG-001 background path): pause/resume still works
- [x] 5.8 Simulator stress (rapid taps on the same correct tile, discovered during apply): only the first tap scores, subsequent taps in the same round are ignored

## 6. Commit & archive

- [x] 6.1 Commit `50100d0 fix: cancel deferred async work and guard animation writes (BUG-003)`
- [x] 6.2 `AUDIT_BUGS.md` status table updated (BUG-003 → ✅ Done) in the archive commit
- [x] 6.3 Archived via `/opsx:archive` to `2026-04-26-fix-bug-003-cancellable-async-after-and-guards`
