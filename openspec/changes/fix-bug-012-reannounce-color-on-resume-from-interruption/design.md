## Context

The pause/resume flow in `LevelGameView` was rewired in BUG-001 (`.onReceive` for `willResignActive` / `didBecomeActive`) and hardened in BUG-002 (`Timer` closure guards). `resumeTimer()` today (around line 1313):

1. Guards on `isGameSessionActive` and the presence of `backgroundTime`.
2. Deducts elapsed wall-clock time from `timeRemaining` (anti-cheat).
3. If `timeRemaining <= 0`, calls `handleTimeUp()` and returns.
4. Re-schedules `gameTimer`.
5. If `isRoundTimerActive` was true, re-starts the round timer with the remaining round time.
6. Clears `backgroundTime`.

What's missing: an audio re-anchor. `announcedColor` (the `@State` holding the current target) is preserved across pause, but the player has no audible reminder of it on resume.

## Goals / Non-Goals

**Goals:**
- Re-speak the current announced color when the game resumes from a pause-causing interruption.
- Keep the change scoped to one line and isolated to `resumeTimer()`.

**Non-Goals:**
- Configure `AVAudioSession` (silent-mode playback, ducking, etc.).
- Listen to `AVAudioSession.interruptionNotification`. The existing `willResignActive`/`didBecomeActive` plumbing already covers every pause-causing interruption that matters here.
- Touch `pauseTimer`, `endGameSession`, the timer scheduling, or `SpeechService`.

## Decisions

### Place the re-speak after the time guard, before timer restart

**Decision:** put the new `speechService.speak(...)` call between the `if timeRemaining <= 0 { handleTimeUp(); return }` guard and the `gameTimer = Timer...` re-schedule.

**Rationale:** if the level timer ran out during the interruption, `handleTimeUp()` ends the level — re-speaking the announced color in that frame is wasted at best, confusing at worst. Placing the call after that guard ensures the audio only plays when the round genuinely resumes. Placing it before the timer re-schedule keeps the audio temporally aligned with "the round is about to resume".

### Don't add a separate `AVAudioSession` interruption listener

**Decision:** rely entirely on the existing `willResignActive` / `didBecomeActive` listeners (BUG-001).

**Rationale:** every BUG-012 trigger we care about (phone call, Control Center swipe, app switch) drives `willResignActive`/`didBecomeActive` reliably on iOS. `AVAudioSession.interruptionNotification` is more granular but its added value (catching audio-only interruptions like AirPods disconnection during silent mode) is far below BUG-012's stated scope. If those edge cases bite later, a follow-up change can introduce the listener and the corresponding `AVAudioSession.setCategory(.playback)` config — which is itself a deliberate design choice (silent-mode audibility) that deserves its own change.

### Don't reconfigure `SpeechService`

**Decision:** keep `SpeechService.speak(_:)` as is.

**Rationale:** `speak(_:)` already calls `audioPlayer?.stop()` first, so re-entrant calls during a resume frame can't overlap. No state inside `SpeechService` needs to change.

## Risks / Trade-offs

- **[Risk]** If the player resumes mid-round but the round timer is about to expire (e.g., 0.2 s remaining), the re-spoken audio (~0.5 s) extends past the round end. → **Mitigation:** `SpeechService.speak()` always stops the in-flight audio when the next call comes, so the re-speak gets cut off at the next round's announce. No leak.

- **[Risk]** A user who briefly switches apps mid-tap could hear the same color spoken twice in quick succession (initial round announce + resume re-announce). → **Mitigation:** `SpeechService` pre-empts; in practice this just means the resume announce overrides the tail of the initial announce, which is fine.

- **[Trade-off]** This change does not configure `AVAudioSession`, so the game audio still respects iOS silent mode. A user with the ringer off won't hear the resume announce — same as today. Documented in non-goals; revisit if it becomes a complaint.

## Migration Plan

No runtime migration. The change is purely additive on the resume path.

**Rollback:** `git revert` the implementation commit. The re-speak disappears; the spec delta in `openspec/specs/level-gameplay/spec.md` can be unwound by a follow-up `MODIFIED` requirement.
