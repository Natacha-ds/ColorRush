## ADDED Requirements

### Requirement: Scores never go negative

`currentScore` and `globalScore` SHALL be clamped to a non-negative range. Any operation that would deduct points (wrong tap, timeout) SHALL floor the resulting value at zero rather than producing a negative number.

#### Scenario: Wrong tap from a low score does not produce a negative value

- **WHEN** the player taps an incorrect tile while their `currentScore` is 5 and the wrong-tap penalty is 10
- **THEN** their `currentScore` becomes 0 (not -5)

#### Scenario: Wrong tap from zero stays at zero

- **WHEN** the player taps an incorrect tile while their `currentScore` is already 0
- **THEN** their `currentScore` remains 0 and the level continues

#### Scenario: Retry refund is consistent with clamping

- **WHEN** the player accumulates penalties whose nominal sum exceeds their `globalScore`, fails the level, and retries
- **THEN** the retry refund applied to `globalScore` equals exactly what was actually subtracted (not the nominal sum), so the player cannot gain points by failing

### Requirement: Lives are the only run-ending mechanism

The level-gameplay session SHALL end a run only when the player runs out of lives. Score-based game-over conditions SHALL NOT exist; in particular, no negative-score check shall fail the run.

#### Scenario: Aggressive wrong tapping at level 1 does not end the run

- **WHEN** the player makes five wrong taps in a row at level 1 without ever reaching `requiredScore`
- **THEN** the level fails by `insufficientScore` at the end of its timer (costing one life), not by `negativeScore` mid-round

#### Scenario: A still-alive run never ends mid-level due to scoring

- **WHEN** the player has at least one life remaining
- **THEN** the run cannot transition to game over until either the lives counter is exhausted or, in the no-lives state, the next failed-level event occurs
