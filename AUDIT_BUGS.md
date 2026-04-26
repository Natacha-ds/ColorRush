# ColorRush — Bug Audit (2026-04-19)

Prioritized backlog produced from auditing the live runtime code.

**Method**: agentic audit on `LevelGameView.swift`, `LevelSystemModels.swift` and related files, cross-referenced with the spec arbitration decisions of 2026-04-19 (code = source of truth).

**Convention**:
- 🔴 P0 — Blocker for App Store submission (crash, data loss, broken scoring)
- 🟠 P1 — Game logic visibly incorrect to the player
- 🟡 P2 — Degraded UX
- 🔵 P3 — Tech debt to address before ads/IAP

Each bug is intended to become an individual OpenSpec change.

---

## 🔴 P0 — App Store blockers

### BUG-001 — Leaked NotificationCenter observers
- **File**: `LevelGameView.swift:1270-1330`
- **Symptom**: memory leaks per game session, possible crash if the observer fires after the view is torn down
- **Cause**: `addObserver(forName:object:queue:using:)` (closure-based) but `removeObserver(self, ...)` (incompatible — the closure API returns a token that must be retained)
- **Fix**: store the `NSObjectProtocol` tokens returned by `addObserver` and pass them to `removeObserver`; `[weak self]` inside the closure

### BUG-002 — Timer firing after view teardown
- **File**: `LevelGameView.swift:607-614, 1355-1362`
- **Symptom**: possible "Unexpectedly found nil" crash if the user exits while the timer expires
- **Cause**: `Timer.scheduledTimer` strongly captures `self`, no `isGameSessionActive` guard inside the closure
- **Fix**: `[weak self]` + `guard let self, self.isGameSessionActive else { return }`

### BUG-003 — Non-cancellable `asyncAfter` closures
- **File**: `LevelGameView.swift:533-537`
- **Symptom**: `startNewRound()` may fire twice; score saved twice
- **Cause**: `DispatchQueue.main.asyncAfter` closures cannot be cancelled when state changes
- **Fix**: replace with `DispatchWorkItem` instances stored in an array, cancelled on `onDisappear` or state changes

### BUG-004 — `globalScore` can become negative
- **File**: `LevelSystemModels.swift:467-490`
- **Symptom**: leaderboard may display negative scores (impossible for the player to beat)
- **Cause**: `addWrongAnswer()` and `addTimeout()` perform `globalScore -= ...` with no clamp
- **Fix**: clamp `globalScore = max(0, globalScore - X)` inside `LevelRun`, OR clamp inside `LeaderboardStore.addScore()`

---

## 🟠 P1 — Player-visible logic

### BUG-008 — Non-punitive refresh L9-10 without re-announcement
- **File**: `LevelGameView.swift:1168-1192`
- **Symptom**: the grid refreshes every 1s but the announced color (audio) is not re-spoken → player gets confused
- **Fix**: either re-announce the color via `SpeechService.speak(...)`, or only shuffle positions without changing colors

### BUG-009 — Misleading streak bonus animation
- **File**: `LevelSystemModels.swift:429-465`
- **Symptom**: the "+20" displayed on screen suggests these 20 points are added on top, when they are already included in `currentScore`
- **Fix**: clarify the animation (label "Streak!" instead of "+20") or change the addition sequence

### BUG-011 — Leaderboard not clamped to ≥ 0
- **File**: `LeaderboardStore.swift:60`
- **Symptom**: corollary of BUG-004 — negative scores persist in the leaderboard
- **Fix**: `addScore(max(0, score), ...)`; covered by BUG-004 if fixed inside `LevelRun`

---

## 🟡 P2 — Degraded UX

### BUG-010 — "Back" button active during the intro
- **File**: `LevelGameView.swift:197-215`
- **Symptom**: tapping "Back" during the 3-second intro → odd UI state
- **Fix**: `.disabled(showLevelIntro)` on the button

### BUG-012 — No audio interruption handling
- **File**: `SpeechService.swift:31-63`
- **Symptom**: an incoming call breaks the audio; the game does not re-announce the color afterwards
- **Fix**: configure `AVAudioSession` + listener on `AVAudioSession.interruptionNotification`

### BUG-013 — `UIImpactFeedbackGenerator` recreated per tap
- **File**: `HapticsService.swift:17-29`
- **Symptom**: haptic feedback drops on rapid taps
- **Fix**: keep a shared instance + 50ms debounce

---

## 🔵 P3 — Tech debt before ads/IAP

### BUG-000 — `GameView.swift` is dead ✅
- **File**: `ColorGame/GameView.swift` (1869 lines)
- **Finding**: mostly dead code, except `ColorTile` (SwiftUI view) used by `LevelGameView`
- **Applied fix**: `ColorTile` extracted into `ColorGame/ColorTile.swift`, `GameView.swift` removed (-1854 lines net). OpenSpec change: `fix-bug-000-remove-dead-gameview` (archived).

### BUG-014 — Potential reference cycles
- **File**: `LevelGameView.swift` (broad)
- **Finding**: to validate via Xcode Memory Graph after 15+ runs
- **Fix**: covered by BUG-002 (`[weak self]` everywhere in timers/closures)

### BUG-015 — Silent `try? JSONDecode`
- **File**: `LeaderboardStore.swift:44-50`
- **Symptom**: corrupted JSON = leaderboard wiped silently
- **Fix**: log on error; harden before storing IAP state

### BUG-016 — `buildValidGrid` with no timeout
- **File**: `LevelGameView.swift:715-846`
- **Symptom**: possible 0.2-0.5s freeze on edge cases
- **Fix**: 100ms timeout + hard-coded fallback grid

### BUG-018 — `CustomizationStore`: dead code
- **File**: `CustomizationStore.swift:45-142`
- **Finding**: `updateEasyDuration`, etc. methods for the legacy mode system — never called
- **Fix**: remove (~100 lines)

### BUG-019 — Race on rapid double-tap "Retry"
- **File**: `LevelSystemModels.swift:390-408`
- **Symptom**: `resetLevelStats()` called twice → inconsistent `globalScore`
- **Fix**: `isResetInProgress` flag or `.disabled` on the button after tap

### BUG-020 — No fallback when `currentLevelConfig == nil`
- **File**: `LevelGameView.swift:1195-1218`
- **Symptom**: extreme edge case → game freezes
- **Fix**: force `isLevelFailed = true` inside the guard

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
