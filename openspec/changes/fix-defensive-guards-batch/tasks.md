## 1. Preparation

- [x] 1.1 Re-read the four touch points and confirmed their exact shape
- [x] 1.2 Confirmed BUG-016 closure rationale (existing `maxAttempts = 20` plus deterministic fallback path already cover the concern; no code change needed)

## 2. BUG-013 — Shared haptics generators

- [x] 2.1 Added `private let lightGenerator` / `heavyGenerator` properties on `HapticsService` (UIKit-guarded)
- [x] 2.2 Replaced per-call instantiation with `lightGenerator.impactOccurred()` / `heavyGenerator.impactOccurred()`

## 3. BUG-015 — Loud leaderboard decode failure

- [x] 3.1 `LeaderboardStore.loadScores(forKey:)` now uses a `do/catch` block that prints `"Leaderboard decode failed for key '\(key)': \(error)"` on decode failure and returns `[]`

## 4. BUG-019 — Re-entrance guard on startNewLevel

- [x] 4.1 Prepended `guard isLevelFailed || isLevelComplete else { return }` to `LevelGameView.startNewLevel()`

## 5. BUG-020 — Defensive failure on nil level config

- [x] 5.1 `handleTimeUp()` now sets `isLevelFailed = true; failedReason = .insufficientScore` before returning when `currentLevelConfig` is nil

## 6. Validation

- [x] 6.1 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 6.2 Device test (haptics): every rapid tap registers a haptic impact, no dropped feedback (verified on physical iPhone — simulator cannot reproduce haptics)
- [x] 6.3 Simulator (retry race): rapid double-tap on "Try Again" produces a single clean transition
- [x] 6.4 Simulator (regression): normal happy path unchanged
- [x] 6.5 Code review (leaderboard): the new `do/catch` in `LeaderboardStore.loadScores` prints on decode failure (verified by visual review)

## 7. Commit & archive

- [ ] 7.1 Commit with message `fix: defensive guards batch (BUG-013/015/016/019/020)` and reference the OpenSpec change in the body
- [ ] 7.2 Update `AUDIT_BUGS.md` status table for all five bugs with the commit hash and archive folder name
- [ ] 7.3 Archive the change via `/opsx:archive fix-defensive-guards-batch`
