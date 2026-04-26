## Context

`LevelGameView.refreshBoardOnly()` runs on levels 9-10 whenever the per-round 1-second timer expires without input. It currently:

1. Disables `isGameActive` (so taps mid-refresh are ignored)
2. Snapshots the previous tile grid for animation purposes
3. Rebuilds a fresh tile grid for the same announced color
4. After 100 ms, re-enables `isGameActive` and restarts the round timer

Step 3 explicitly does **not** call `speechService.speak(...)`, with a comment that says so. That decision predates the audit and is the bug.

`SpeechService.speak(_:)` plays a pre-recorded color name audio file and stops any currently-playing audio first (`SpeechService.swift:33`). The audio files are short — well under the 1-second refresh cadence — so re-announcing on every refresh produces no overlap and no perceptible audio churn.

## Goals / Non-Goals

**Goals:**
- Make the audio cue (the announced color) re-fire on every non-punitive refresh on levels 9-10.
- Touch only the audio reinforcement; do not change scoring, refresh cadence, tile generation, or any other gameplay element.

**Non-Goals:**
- Re-design levels 9-10 (e.g., move to a positional shuffle instead of a color shuffle).
- Add throttling / debounce on the audio. The 1-second cadence is already a natural floor.
- Replace the audio asset pipeline.

## Decisions

### Re-announce on every refresh, unconditionally

**Decision:** call `speechService.speak(colorName(for: announcedColor))` on every entry into `refreshBoardOnly()`, with no skip / debounce condition.

**Rationale:** the announced color does not change inside this code path, so a "skip if same as previous announce" optimisation would never fire. The existing `SpeechService.speak()` already stops in-flight audio, so unconditional re-speak is correct, idempotent, and the simplest possible code.

### Alternative rejected

**Re-announce only when the round timer was about to expire (debounce)**: would add state tracking ("when did we last speak?") for a sub-1 s window that is already gated by the 1 s round timer. No win.

## Risks / Trade-offs

- **[Risk]** A player who is rapidly tapping might trigger a refresh and a normal round announce within the same ~100 ms window, causing audio cut-off. → **Mitigation:** `SpeechService.speak()` always stops the current player first, so the latest announce wins. Worst case is the previous audio is cut short, never overlap.

- **[Trade-off]** The audio plays once per second on levels 9-10 if the player is idle, which could feel repetitive. → Acceptable: idle play is supposed to be a discouraging signal at the highest difficulty. If we ever decide it's annoying, the fix is to add a "throttle to N s" wrapper on top, in a follow-up.

## Migration Plan

No runtime migration. Player-visible change is purely audio: levels 9-10 now keep the announce in sync with the board.

**Rollback:** `git revert` the implementation commit. The re-announce disappears, the spec delta in `openspec/specs/level-gameplay/spec.md` can be unwound by a follow-up `MODIFIED` requirement.
