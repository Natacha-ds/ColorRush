## ADDED Requirements

### Requirement: Leaderboard includes the Color Match mode without difficulty filter

The leaderboard SHALL offer Color Match as a selectable game type. When it is selected, the difficulty filter SHALL be hidden and the single Color Match bucket (local top scores and Game Center rank/top entries from `tonic.colorrush.leaderboard.colormatch`) SHALL be shown. The Home "BEST" header SHALL account for Color Match scores.

#### Scenario: View Color Match scores
- **WHEN** the player selects Color Match in the leaderboard
- **THEN** no difficulty filter is shown and the Color Match scores are listed, or the empty state if none

#### Scenario: Existing buckets preserved
- **WHEN** the app updates from a version without Color Match
- **THEN** previously recorded scores for the other modes are still displayed under their (mode, difficulty) buckets
