## ADDED Requirements

### Requirement: Color voice audio is spoken in the player's locale

When `SpeechService.speak(_:)` plays the announced-color audio (initial round, resume from interruption, or non-punitive refresh on levels 9-10), the audio file resolved by the bundle SHALL match the player's current locale when one is supported. For French-locale players the mp3 SHALL pronounce the French color name (e.g., "rouge"); for English-locale players it SHALL pronounce the English name (e.g., "red"); for any other locale the system SHALL fall back to the English file.

#### Scenario: French-locale gameplay

- **WHEN** the player runs the app on a French-locale device and a round announces the color red
- **THEN** the audio cue plays the French pronunciation "rouge" rather than the English "red"

#### Scenario: English-locale gameplay

- **WHEN** the player runs the app on an English-locale device and a round announces the color red
- **THEN** the audio cue plays the English pronunciation "red"

#### Scenario: Unsupported-locale fallback

- **WHEN** the player runs the app on a German or Spanish locale device (not yet localized)
- **THEN** the audio cue falls back to the English mp3 with no error, no silent gap, and the gameplay flow continues normally
