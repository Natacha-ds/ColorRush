## ADDED Requirements

### Requirement: Non-punitive refresh re-speaks the announced color

On levels with the non-punitive refresh mechanic (levels 9-10), every refresh of the tile grid SHALL re-speak the current announced color via `SpeechService.speak(_:)`, so the audio cue stays in sync with the visual board.

#### Scenario: Idle on level 9 — color is re-spoken on each refresh

- **WHEN** the player is on level 9 and does not tap, allowing the 1-second round timer to expire repeatedly
- **THEN** the announced color is audibly re-spoken on each refresh, with no audible overlap (each new playback pre-empts the previous)

#### Scenario: Tap mid-refresh — round transitions cleanly

- **WHEN** the player taps a correct tile on level 9 right after a refresh has just fired
- **THEN** the next round's announce plays cleanly (the in-flight refresh announce is pre-empted by `SpeechService` before the new round announce starts)
