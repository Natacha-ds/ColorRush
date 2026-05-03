## 1. Preparation

- [x] 1.1 Confirmed `resumeTimer()` structure (time-deduction → handleTimeUp guard → game timer restart → optional round timer restart → clear backgroundTime)
- [x] 1.2 Confirmed placement target (between the `handleTimeUp()` guard and the `gameTimer` re-schedule)

## 2. Implementation

- [x] 2.1 Added `speechService.speak(colorName(for: announcedColor))` inside `resumeTimer()` after the `handleTimeUp()` guard, before the `gameTimer` re-schedule

## 3. Validation

- [x] 3.1 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 3.2 Simulator (resume re-anchor): announced color is re-spoken as the round resumes
- [x] 3.3 Simulator (resume after expiry): no resume re-speak fires when the level ended during the interruption
- [x] 3.4 Simulator regression: normal round transitions announce the new color exactly once

## 4. Commit & archive

- [ ] 4.1 Commit with message `fix: re-announce color on resume from interruption (BUG-012)` and reference the OpenSpec change in the body
- [ ] 4.2 Update `AUDIT_BUGS.md` status table: BUG-012 → ✅ Done with the commit hash and archive folder name
- [ ] 4.3 Archive the change via `/opsx:archive fix-bug-012-reannounce-color-on-resume-from-interruption`
