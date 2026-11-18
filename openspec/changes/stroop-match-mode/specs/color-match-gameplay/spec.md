## ADDED Requirements

### Requirement: Color Match card display

A Color Match session SHALL show one card at a time: a color name written at the center of the screen, over a full-screen background colored with either the written color or a different color. The word SHALL be displayed in a neutral color so that only its meaning is compared with the background.

#### Scenario: Matching card
- **WHEN** a card is generated whose background color equals the named color
- **THEN** the screen shows that color's name at the center over a background of the same color, and ✓ is the correct answer

#### Scenario: Non-matching card
- **WHEN** a card is generated whose background color differs from the named color
- **THEN** ✗ is the correct answer

#### Scenario: Balanced answers
- **WHEN** many cards are generated in a session
- **THEN** roughly half are matching, and no more than 3 consecutive cards share the same correct answer

### Requirement: Binary answer input

The screen SHALL present two answer buttons, ✓ ("same color") and ✗ ("different color"). Each button SHALL have a localized accessibility label.

#### Scenario: Correct answer
- **WHEN** the player taps the button matching the card's correct answer
- **THEN** the score increases by 1, success feedback plays, and the next card appears immediately

#### Scenario: Wrong answer
- **WHEN** the player taps the wrong button
- **THEN** error haptic/sound feedback plays and the run ends

### Requirement: Accelerating countdown

Each card SHALL have a visible countdown. The time allowed per card SHALL decrease as the player's correct-answer count grows, with a minimum floor of 0.7 s. The mode SHALL NOT have difficulty levels.

#### Scenario: Time shrinks over the run
- **WHEN** the player has answered N correct cards
- **THEN** the time budget for the next card is strictly less than or equal to the budget at N−1, and never below 0.7 s

#### Scenario: Timeout
- **WHEN** the countdown reaches zero before an answer
- **THEN** it is treated as a wrong answer and the run ends

### Requirement: One mistake ends the run

The score SHALL equal the number of cards answered correctly. The first wrong answer or timeout SHALL end the run, record the score in the local leaderboard bucket for Color Match, submit it to the Game Center leaderboard `tonic.colorrush.leaderboard.colormatch`, and show a game-over screen with the score, the best score, a retry action and a home action.

#### Scenario: Mistake on the 12th card
- **WHEN** the player answers 11 cards correctly and then answers the 12th wrongly
- **THEN** the final score is 11, it is saved locally, submitted to Game Center, and the game-over screen is shown

#### Scenario: Game Center unavailable
- **WHEN** the player is not authenticated with Game Center at game over
- **THEN** the score is still saved locally and the game-over screen is shown without error

#### Scenario: Retry
- **WHEN** the player taps retry on the game-over screen
- **THEN** a new session starts with score 0

### Requirement: Backgrounding pauses the session

The countdown SHALL NOT run while the app is not active.

#### Scenario: App goes to background mid-card
- **WHEN** the app resigns active during a card and returns later
- **THEN** the remaining time on the card is unchanged from when it left
