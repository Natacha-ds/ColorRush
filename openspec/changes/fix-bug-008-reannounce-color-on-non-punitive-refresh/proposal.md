## Why

Levels 9-10 use a "non-punitive refresh" mechanic: every 1 second of inaction, the board reshuffles its tiles while keeping the same announced color. The current `refreshBoardOnly()` implementation explicitly skips re-speaking the color, so the player loses the audio reinforcement that anchors gameplay. After a few refreshes the player is staring at a brand-new visual layout with no audible reminder of which color is the target — the high-difficulty levels then feel arbitrarily punishing rather than challenging.

Re-announcing the (unchanged) color on every refresh is a one-line change that closes BUG-008 and aligns the implementation with the design intent in the product spec ("colors change every second, but the target stays announced").

## What Changes

- In `LevelGameView.swift` `refreshBoardOnly()`, call `speechService.speak(colorName(for: announcedColor))` on every refresh, replacing the existing "don't speak it again" comment.
- Update the inline comment to reflect the new behavior.
- No change to the announced-color value, no change to the refresh cadence, no change to scoring.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `level-gameplay`: ADD a requirement that the non-punitive refresh on levels 9-10 re-speaks the announced color audibly on each refresh, keeping the audio cue in sync with the visual board.

## Impact

- **Code**: ~2 lines net inside `refreshBoardOnly()`.
- **Build**: must remain green.
- **Runtime**: levels 9-10 produce one extra audio playback per refresh (same color file as the initial announce); `SpeechService.speak()` already pre-empts any in-flight audio so there is no overlap.
- **Audio assets**: none new — uses the existing `Red-voice.mp3` / `Blue-voice.mp3` / `Green-voice.mp3` / `Yellow-voice.mp3` files.
- **Tests**: no tests exist today.
- **Migration**: none.
