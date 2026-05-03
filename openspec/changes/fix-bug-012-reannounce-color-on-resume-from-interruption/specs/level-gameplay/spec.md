## ADDED Requirements

### Requirement: Resume from interruption re-anchors the audio cue

When the level-gameplay session resumes after a pause-causing interruption (backgrounding, phone call, Control Center, app switch, etc.) and the level timer has not expired during the interruption, the application SHALL re-speak the current announced color via `SpeechService.speak(_:)`, so the player has an immediate audio anchor on the active round.

#### Scenario: Resume from a backgrounded session re-speaks the color

- **WHEN** the player is mid-round, the announced color is "Red", they background the app for a few seconds, and they return
- **THEN** "Red" is re-spoken as the round resumes (in addition to the existing time-deduction)

#### Scenario: Resume after the level timer has already expired does not re-speak

- **WHEN** the player backgrounds the app for longer than the remaining level time, so resuming triggers `handleTimeUp()` immediately
- **THEN** no re-speak occurs (no audio is played for a level that ended during the interruption)

#### Scenario: Normal round transition is unchanged

- **WHEN** the player taps a correct tile within an uninterrupted round and the next round starts
- **THEN** the new round announces its new color exactly once (the resume re-speak does not fire on normal round transitions)
