## Why

When a phone call, Control Center swipe, or app switch interrupts gameplay, iOS fires `willResignActive` and `LevelGameView` (since BUG-001) calls `pauseTimer()`. On return, `didBecomeActive` fires and `resumeTimer()` runs — but it never re-speaks the announced color. Players come back from a 30-second call to a tile grid and no audio reminder of which color they were trying to match.

The audit (BUG-012) flagged this as a P2 UX issue. The audit recommended a broader `AVAudioSession.interruptionNotification` listener; in practice the existing `willResignActive`/`didBecomeActive` plumbing already covers every interruption that matters here, and the only thing missing is the audio re-anchor itself. A one-line fix in `resumeTimer()` closes the player-visible symptom without dragging in unrelated audio-policy questions.

## What Changes

- In `LevelGameView.swift` `resumeTimer()`, add a single call: `speechService.speak(colorName(for: announcedColor))`. Place it after the `timeRemaining -= elapsedTime` math and the `handleTimeUp()` guard, before the game timer is restarted, so the audio cue lands at the moment the round resumes visually.
- No change to `pauseTimer`, `endGameSession`, the timer scheduling, or `SpeechService` itself.
- No `AVAudioSession` configuration. Silent-mode and ducking concerns are out of scope.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `level-gameplay`: ADD a requirement that on resume from any pause-causing interruption (backgrounding, phone call, etc.), the announced color is re-spoken so the player has an immediate audio anchor on the active round.

## Impact

- **Code**: 1 line added inside `resumeTimer()`.
- **Build**: must remain green.
- **Runtime / player behavior**:
  - Resume from a background event now plays the current announced color audio in addition to restoring the timer state.
  - No change to the time-deduction anti-cheat behavior, the round timer state, or any visual element.
- **Audio assets**: none new (uses the existing `*-voice.mp3` files via `SpeechService.speak`).
- **Tests**: no tests exist today.
- **Migration**: none.
