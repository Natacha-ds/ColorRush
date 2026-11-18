## ADDED Requirements

### Requirement: Selected mode shows its rules on the mode step

The "Pick a Mode" step SHALL list Color Match alongside the existing modes, with a localized title and swatch. Selecting a mode SHALL display that mode's rules in a panel on the same screen, updating immediately when the selection changes.

#### Scenario: Rules follow the selection
- **WHEN** the player taps the Color Match card
- **THEN** the rules panel shows the Color Match rules (a color name over a colored background; tap ✓ if they are the same color, ✗ otherwise; the timer speeds up; one mistake ends the run)

#### Scenario: Switching mode
- **WHEN** the player then taps Color ONLY
- **THEN** the rules panel shows the Color ONLY rules

### Requirement: Primary button is "Play" and Color Match skips difficulty

The primary button of the mode step SHALL read "Play" for every mode. For Color Only and Color and Text it SHALL go to the "How Hard?" step as before. For Color Match it SHALL start the game directly, without a difficulty step, opening `ColorMatchGameView` instead of `LevelGameView`.

#### Scenario: Play Color Match
- **WHEN** the player selects Color Match and taps "Play"
- **THEN** `ColorMatchGameView` opens without a difficulty step, and a `run_started` event is logged with `gameType = colorMatch`

#### Scenario: Existing modes unchanged
- **WHEN** the player selects Color Only or Color and Text and taps "Play"
- **THEN** the "How Hard?" step appears, and "Let's go" opens `LevelGameView` exactly as before
