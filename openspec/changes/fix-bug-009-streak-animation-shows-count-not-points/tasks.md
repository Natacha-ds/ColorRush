## 1. Preparation

- [x] 1.1 Confirmed the four touch points in `LevelGameView.swift` (declaration, call site, `.onChange` handler, struct definition)
- [x] 1.2 Confirmed `levelRun.currentStreak` is incremented before `lastBonusEarned` fires in `addCorrectAnswer()`

## 2. Implementation

- [x] 2.1 Renamed `streakBonusAmount` → `streakDisplayCount`
- [x] 2.2 `.onChange(of: levelRun.lastBonusEarned)` now captures `levelRun.currentStreak` instead of `newValue`
- [x] 2.3 Call site updated to `StreakAnimationView(streakCount: streakDisplayCount)`
- [x] 2.4 `StreakAnimationView` parameter renamed `bonusAmount` → `streakCount`
- [x] 2.5 Displayed text changed from `"Streak +\(bonusAmount) pt"` to `"\(streakCount) in a row!"`

## 3. Validation

- [x] 3.1 `grep -n "bonusAmount\|streakBonusAmount"` returns no matches (exit 1)
- [x] 3.2 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 3.3 Simulator (Color Only): "🔥 10 in a row!" displayed at milestone, score already reflects the bonus
- [x] 3.4 Simulator (Color+Text): "🔥 5 in a row!" displayed at milestone
- [x] 3.5 Simulator (regression): wrong tap resets streak, no animation until the next fresh milestone

## 4. Commit & archive

- [ ] 4.1 Commit with message `fix: streak animation shows count not points (BUG-009)` and reference the OpenSpec change in the body
- [ ] 4.2 Update `AUDIT_BUGS.md` status table: BUG-009 → ✅ Done with the commit hash and archive folder name
- [ ] 4.3 Archive the change via `/opsx:archive fix-bug-009-streak-animation-shows-count-not-points`
