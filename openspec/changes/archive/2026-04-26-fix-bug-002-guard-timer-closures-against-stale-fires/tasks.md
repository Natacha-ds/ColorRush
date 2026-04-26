## 1. Preparation

- [x] 1.1 Confirmed the three `Timer.scheduledTimer` call sites in `LevelGameView.swift`: `gameTimer` initial (~line 601), `roundTimer` (~line 1135), `gameTimer` resume (~line 1287)
- [x] 1.2 Confirmed `endGameSession()` flips `isGameSessionActive = false` and `endRoundTimer()` flips `isRoundTimerActive = false`

## 2. Add guards inside each timer closure

- [x] 2.1 Added `guard isGameSessionActive else { return }` at the top of the initial `gameTimer` closure
- [x] 2.2 Added `guard isRoundTimerActive else { return }` at the top of the `roundTimer` closure
- [x] 2.3 Added `guard isGameSessionActive else { return }` at the top of the resume `gameTimer` closure

## 3. Validation

- [x] 3.1 `grep -A1 "scheduledTimer" ColorGame/LevelGameView.swift` shows each closure starts with the appropriate `guard ... else { return }`
- [x] 3.2 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 3.3 Simulator regression test (happy path): level timer and round timer count down normally, level finishes correctly
- [x] 3.4 Simulator regression test (BUG-001 path): background/foreground deduction still works
- [x] 3.5 Simulator stress test: rapid Back during gameplay produces no crash, no zombie countdown, no leftover state

## 4. Commit & archive

- [x] 4.1 Commit `c78af98 fix: guard Timer closures against stale fires (BUG-002)`
- [x] 4.2 `AUDIT_BUGS.md` status table updated (BUG-002 → ✅ Done) in the archive commit
- [x] 4.3 Archived via `/opsx:archive` to `2026-04-26-fix-bug-002-guard-timer-closures-against-stale-fires`
