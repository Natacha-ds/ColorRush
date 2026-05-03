## ADDED Requirements

### Requirement: Streak-bonus animation shows the streak count, not the bonus delta

The streak-bonus animation overlay SHALL display the consecutive-correct-answer count reached at the milestone (e.g., "10 in a row!"), not the bonus point delta. The score itself SHALL continue to be incremented by the bonus at the moment of the milestone, but the on-screen label SHALL NOT imply that the displayed number is a separate, yet-to-be-added point award.

#### Scenario: Color Only — milestone at 10 consecutive correct

- **WHEN** the player reaches 10 consecutive correct taps in Color Only mode
- **THEN** the animation overlay reads "🔥 10 in a row!" (and the score has already been incremented by the streak bonus)

#### Scenario: Color+Text — milestone at 5 consecutive correct

- **WHEN** the player reaches 5 consecutive correct taps in Color+Text mode
- **THEN** the animation overlay reads "🔥 5 in a row!"

#### Scenario: Wrong tap resets the streak

- **WHEN** the player has built a streak below the next milestone and then taps incorrectly
- **THEN** `currentStreak` resets to zero and no animation fires until the next milestone is reached on a fresh streak
