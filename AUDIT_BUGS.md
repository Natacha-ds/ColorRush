# ColorRush — Bug Audit (2026-04-19)

Prioritized backlog produced from auditing the live runtime code.

**Method**: agentic audit on `LevelGameView.swift`, `LevelSystemModels.swift` and related files, cross-referenced with the spec arbitration decisions of 2026-04-19 (code = source of truth).

**Convention**:
- 🔴 P0 — Blocker for App Store submission (crash, data loss, broken scoring)
- 🟠 P1 — Game logic visibly incorrect to the player
- 🟡 P2 — Degraded UX
- 🔵 P3 — Tech debt to address before ads/IAP

Each bug is intended to become an individual OpenSpec change.

## Status

| Bug | Priority | Status | Reference |
|---|---|---|---|
| BUG-000 | P3 | ✅ Done | commit `3216f80` / archive `2026-04-26-fix-bug-000-remove-dead-gameview` |
| BUG-001 | P0 | ✅ Done | commit `2c37b0b` / archive `2026-04-26-fix-bug-001-leaked-notification-observers` |
| BUG-002 | P0 | ✅ Done | commit `c78af98` / archive `2026-04-26-fix-bug-002-guard-timer-closures-against-stale-fires` |
| BUG-003 | P0 | ✅ Done | commit `50100d0` / archive `2026-04-26-fix-bug-003-cancellable-async-after-and-guards` |
| BUG-004 | P0 | ✅ Done | commit `dd75ba2` / archive `2026-04-26-fix-bug-004-clamp-scores-and-remove-negative-game-over` |
| BUG-008 | P1 | ✅ Done | commit `a8b66a8` / archive `2026-04-26-fix-bug-008-reannounce-color-on-non-punitive-refresh` |
| BUG-009 | P1 | ✅ Done | commit `2a07678` / archive `2026-05-03-fix-bug-009-streak-animation-shows-count-not-points` |
| BUG-010 | P2 | ✅ Done | corollary of BUG-003 (intro auto-dismiss now cancelled on dismiss) |
| BUG-011 | P1 | ✅ Done | corollary of BUG-004 (commit `dd75ba2`) |
| BUG-012 | P2 | ✅ Done | commit `7f21eae` / archive `2026-05-03-fix-bug-012-reannounce-color-on-resume-from-interruption` |
| BUG-013 | P2 | ✅ Done | commit `4331f12` / archive `2026-05-03-fix-defensive-guards-batch` |
| BUG-014 | P3 | ✅ Done | corollary of BUG-001/002/003 (no code change needed) |
| BUG-015 | P3 | ✅ Done | commit `4331f12` / archive `2026-05-03-fix-defensive-guards-batch` |
| BUG-016 | P3 | ✅ Done | closed without code change (maxAttempts + deterministic fallback already cover the concern); see archive `2026-05-03-fix-defensive-guards-batch` |
| BUG-018 | P3 | ✅ Done | commit `cd86273` / archive `2026-04-26-fix-bug-018-remove-customization-subsystem` |
| BUG-019 | P3 | ✅ Done | commit `4331f12` / archive `2026-05-03-fix-defensive-guards-batch` |
| BUG-020 | P3 | ✅ Done | commit `4331f12` / archive `2026-05-03-fix-defensive-guards-batch` |

---

## 🔴 P0 — App Store blockers

### BUG-001 — Leaked NotificationCenter observers ✅
- **File**: `LevelGameView.swift:1270-1330` (former location of the broken setup/remove helpers)
- **Symptom**: memory leaks per game session, possible crash if the observer fires after the view is torn down
- **Cause**: `addObserver(forName:object:queue:using:)` (closure-based) but `removeObserver(self, ...)` (incompatible — the closure API returns a token that must be retained, and `self` is a struct here)
- **Applied fix**: replaced the manual setup/remove plumbing with idiomatic SwiftUI `.onReceive(NotificationCenter.default.publisher(for:))` modifiers — SwiftUI binds the subscription to the view lifetime, making the leak structurally impossible. OpenSpec change: `fix-bug-001-leaked-notification-observers` (archived).

### BUG-002 — Timer firing after view teardown ✅
- **Files updated**: `LevelGameView.swift` — three `Timer.scheduledTimer` call sites (initial `gameTimer`, `roundTimer`, resume `gameTimer`)
- **Symptom**: possible "Unexpectedly found nil" crash and silent state corruption (timer ticking past 0, restart on stale state) if a tick fires after `.onDisappear`/`endGameSession` / `endRoundTimer`
- **Cause**: closures had no guard; `LevelGameView` is a struct so `[weak self]` does not apply
- **Applied fix**: added `guard isGameSessionActive else { return }` at the top of both `gameTimer` closures and `guard isRoundTimerActive else { return }` at the top of the `roundTimer` closure. Stale ticks are now no-ops. OpenSpec change: `fix-bug-002-guard-timer-closures-against-stale-fires` (archived).

### BUG-003 — Non-cancellable `asyncAfter` closures ✅
- **File**: `LevelGameView.swift` — 10 `asyncAfter` sites (5 gameplay-state, 3 animation flags, 2 intentional)
- **Symptom**: rapid double-tap could double-execute round transitions; Back during the 3 s intro mutated `levelRun` after dismiss; Back during the 100 ms activation window flipped `isGameActive` on a dead view; rapid taps on the same correct tile cumulated points within the 300 ms transition window (discovered during apply)
- **Cause**: closures had no cancellation mechanism, several lacked internal guards, and `handleTileTap` had no in-round re-entrance gate
- **Applied fix**: 5 state-mutating sites converted to `DispatchWorkItem` with three `@State` slots cancelled in `endGameSession()`; 3 benign sites guarded with `isGameSessionActive`; 2 intentional sites left alone; in-round re-entrance closed by flipping `isGameActive = false` at the top of `handleTileTap`. OpenSpec change: `fix-bug-003-cancellable-async-after-and-guards` (archived).

### BUG-004 — `globalScore` can become negative ✅
- **Files updated**: `LevelSystemModels.swift` (`addWrongAnswer`, `addTimeout`), `LevelGameView.swift` (negative-score game-over removed, `LevelFailureReason.negativeScore` cleaned up)
- **Player-visible symptom**: a wrong tap on level 1 ended the run instantly (`Score < 0` screen) — way more punishing than the announced lives system
- **Applied fix**: scores are clamped to ≥ 0 at the source, and `levelPenalties` tracks the *actual* amount subtracted (not the nominal) so retry refunds stay correct. The negative-score game-over path was removed entirely; lives are now the only run-ending mechanism. OpenSpec change: `fix-bug-004-clamp-scores-and-remove-negative-game-over` (archived).

---

## 🟠 P1 — Player-visible logic

### BUG-008 — Non-punitive refresh L9-10 without re-announcement ✅
- **File**: `LevelGameView.swift` `refreshBoardOnly()`
- **Symptom**: the grid refreshes every 1 s but the announced color (audio) was not re-spoken, leaving the player without audio reinforcement against a brand-new visual layout
- **Applied fix**: `refreshBoardOnly()` now calls `speechService.speak(colorName(for: announcedColor))` on every refresh. `SpeechService.speak` already stops in-flight audio so re-announces pre-empt cleanly. OpenSpec change: `fix-bug-008-reannounce-color-on-non-punitive-refresh` (archived).

### BUG-009 — Misleading streak bonus animation ✅
- **File**: `LevelGameView.swift` (`StreakAnimationView` and the `.onChange(of: lastBonusEarned)` handler)
- **Symptom**: animation read "🔥 Streak +20 pt"; the bonus was already counted in `currentScore`, so "+20 pt" misled players into expecting another addition
- **Applied fix**: switched the displayed metric from the bonus point delta to the streak length reached. The animation now reads "🔥 X in a row!" using `levelRun.currentStreak` captured at the milestone. Score math unchanged. OpenSpec change: `fix-bug-009-streak-animation-shows-count-not-points` (archived).

### BUG-011 — Leaderboard not clamped to ≥ 0 ✅
- **File**: `LeaderboardStore.swift:60`
- **Symptom**: corollary of BUG-004 — negative scores persist in the leaderboard
- **Resolved as corollary**: with `globalScore` clamped at the source (BUG-004), `LeaderboardStore.addScore` cannot receive a negative value anymore. No defensive clamp added at the LeaderboardStore level.

---

## 🟡 P2 — Degraded UX

### BUG-010 — "Back" button active during the intro ✅
- **File**: `LevelGameView.swift`
- **Symptom**: tapping "Back" during the 3-second intro left the view in an odd state because the auto-dismiss closure still fired afterwards and mutated `levelRun`
- **Resolved as corollary**: BUG-003 made the intro auto-dismiss cancellable via `pendingIntroDismiss`, which `endGameSession()` cancels in `.onDisappear`. Tapping Back during the intro now cleanly cancels the auto-dismiss; no mutation of `levelRun` from a dead view. The audit also suggested `.disabled(showLevelIntro)` on the Back button, but allowing Back during the intro is actually better UX (the player can bail early), so we keep it tappable.

### BUG-012 — No audio interruption handling ✅
- **File**: `LevelGameView.swift` `resumeTimer()`
- **Symptom**: after a phone call (or any willResignActive interruption), the player returned to the game with no fresh audio cue for the announced color
- **Applied fix**: added a single `speechService.speak(colorName(for: announcedColor))` inside `resumeTimer()` after the `handleTimeUp()` guard, so the announced color is re-anchored on resume only when the round genuinely continues. The broader `AVAudioSession` setup the audit also suggested (silent-mode policy, ducking) was deliberately left out of scope — those are orthogonal product decisions that deserve their own change if they ever bite. OpenSpec change: `fix-bug-012-reannounce-color-on-resume-from-interruption` (archived).

### BUG-013 — `UIImpactFeedbackGenerator` recreated per tap ✅
- **File**: `HapticsService.swift`
- **Symptom**: haptic feedback dropped on rapid taps because each call instantiated a new generator
- **Applied fix**: `HapticsService` now holds shared `UIImpactFeedbackGenerator` instances at class scope and reuses them. Verified on physical iPhone (simulator cannot reproduce haptics). OpenSpec change: `fix-defensive-guards-batch` (archived).

---

## 🔵 P3 — Tech debt before ads/IAP

### BUG-000 — `GameView.swift` is dead ✅
- **File**: `ColorGame/GameView.swift` (1869 lines)
- **Finding**: mostly dead code, except `ColorTile` (SwiftUI view) used by `LevelGameView`
- **Applied fix**: `ColorTile` extracted into `ColorGame/ColorTile.swift`, `GameView.swift` removed (-1854 lines net). OpenSpec change: `fix-bug-000-remove-dead-gameview` (archived).

### BUG-014 — Potential reference cycles ✅
- **File**: `LevelGameView.swift` (broad)
- **Finding**: the audit flagged a generic "reference cycle" suspicion to be validated via Xcode Memory Graph after 15+ runs.
- **Resolved as corollary**: closed by the combination of BUG-001 (replaced manual `NotificationCenter` observers with SwiftUI `.onReceive` modifiers — lifetime managed by SwiftUI), BUG-002 (added `isGameSessionActive` / `isRoundTimerActive` guards inside Timer closures so they no-op on stale state), and BUG-003 (made deferred `asyncAfter` work cancellable via `DispatchWorkItem`). No remaining closure pattern captures long-lived state in a way that would create a cycle. `LevelGameView` is a SwiftUI `struct`, so `[weak self]` does not apply; the structural changes above are the right equivalent.

### BUG-015 — Silent `try? JSONDecode` ✅
- **File**: `LeaderboardStore.swift` `loadScores(forKey:)`
- **Symptom**: a corrupted JSON wiped the leaderboard silently
- **Applied fix**: replaced `try?` with `do/catch` that prints `"Leaderboard decode failed for key '<key>': <error>"` and returns `[]` as a safe fallback. Critical hardening before any IAP state lands in `UserDefaults`. OpenSpec change: `fix-defensive-guards-batch` (archived).

### BUG-016 — `buildValidGrid` with no timeout ✅
- **File**: `LevelGameView.swift` `buildValidGrid()` and `buildValidGridWithText()`
- **Audit hypothesis**: 0.2-0.5 s freeze on pathological inputs
- **Closed without code change**: code review showed `maxAttempts = 20` (microseconds per iteration) and a deterministic fallback path that always returns a valid grid. No real freeze risk; the audit's hypothesis didn't survive code review. Rationale documented in `fix-defensive-guards-batch/design.md` (archived).

### BUG-018 — Dead customization subsystem ✅
- **Files removed**:
  - `CustomizeModeSheet.swift` (619 lines)
  - `CustomizationStore.swift` (142 lines)
  - `GameCustomization.swift` (150 lines)
  - `LevelGameView.swift:17` — orphan `@StateObject` declaration
- **Finding**: the entire customization subsystem (legacy difficulty-mode tuning UI) was dead. Initial audit underestimated the scope ("~100 lines"); actual scope was ~912 lines across 3 files plus one orphan declaration.
- **Applied fix**: deleted the three files and removed the unused `@StateObject` from `LevelGameView.swift`. Net diff: -912 / +135 (the +135 is the OpenSpec change artifacts). OpenSpec change: `fix-bug-018-remove-customization-subsystem` (archived).

### BUG-019 — Race on rapid double-tap "Retry" ✅
- **File**: `LevelGameView.swift` `startNewLevel()`
- **Symptom**: rapid double-tap on "Try Again" called `startNewLevel()` twice
- **Applied fix**: prepended `guard isLevelFailed || isLevelComplete else { return }` to `startNewLevel()`. Both flags flip false on the first call, so the second rapid call is a clean no-op. OpenSpec change: `fix-defensive-guards-batch` (archived).

### BUG-020 — No fallback when `currentLevelConfig == nil` ✅
- **File**: `LevelGameView.swift` `handleTimeUp()`
- **Symptom**: if `currentLevelConfig` was nil at time-up, the view returned silently and froze
- **Applied fix**: the guard now sets `isLevelFailed = true; failedReason = .insufficientScore` before returning, routing the player into the existing failure UI instead of freezing. OpenSpec change: `fix-defensive-guards-batch` (archived).

---

## Discarded findings

| ID | Reason |
|---|---|
| BUG-005 | Required scores ≠ MD: arbitrated, code = source of truth |
| BUG-006 | Wrong tap does not cost a life: arbitrated, code behavior = intended |
| BUG-007 | Color+Text point progression: design decision, not a bug |
| BUG-017 | `#if DEBUG` leaking in prod: false positive, stripped at compile time |

---

## Proposed plan of attack

1. **Cleanup phase** (low risk, big clarity gain)
   - BUG-000: remove `GameView.swift` ✅ done
   - BUG-018: clean up `CustomizationStore`

2. **Memory & lifecycle phase** (most critical for the App Store)
   - BUG-001 + BUG-002 + BUG-014: `[weak self]` pattern + observer tokens, treated as one coherent block
   - BUG-003: cancellable `DispatchWorkItem`s

3. **Scoring phase** (visible logic)
   - BUG-004 + BUG-011: clamp `globalScore`/leaderboard to 0
   - BUG-009: clarify streak UX

4. **UX polish phase**
   - BUG-008, BUG-010, BUG-012, BUG-013

5. **Robustness phase**
   - BUG-015, BUG-016, BUG-019, BUG-020

Each bug → one OpenSpec change (`/opsx:propose fix-bug-NNN`) before fix.
