## ADDED Requirements

### Requirement: Share my best button

`LeaderboardView` SHALL render a "Share my best" button above the ranked list (and below the difficulty selector / rank pill region). The button SHALL combine the `square.and.arrow.up` icon and a localized uppercase label (e.g. `SHARE MY BEST` in English, `PARTAGER MON BEST` or equivalent in French; final wording locked during implementation). Tapping it SHALL invoke the shared share pipeline (see `share-score` capability) with:
- `score` = the local player's best score for the currently selected `(GameType, MistakeTolerance)` filter, sourced from the same data the leaderboard view already uses to render the local player row.
- `gameType` = the currently selected `GameType` in the mode segmented control.
- `mistakeTolerance` = the currently selected `MistakeTolerance` in the difficulty chip selector.
- `source` = `.leaderboard`

#### Scenario: Share my best for the active filter
- **WHEN** the user has a local best of 820 in `(.colorOnly, .easy)` and the filters are set to PURE / ROOKIE
- **THEN** the "Share my best" button is enabled and tapping it presents the share sheet with `score = 820`, `gameType = .colorOnly`, `mistakeTolerance = .easy`, `source = .leaderboard`

#### Scenario: Score reflects the currently selected filter
- **WHEN** the user switches the mode from PURE to COLOR+WORD with a local best of 1420 in `(.colorAndText, currentTolerance)`
- **THEN** the "Share my best" button reflects the new bucket's score (1420), and tapping it shares that value with `gameType = .colorAndText`

### Requirement: Share my best disabled when no local score exists

When the local player has no score recorded for the currently selected `(GameType, MistakeTolerance)` filter, the "Share my best" button SHALL be rendered in a disabled visual state (muted opacity matching the existing disabled pattern, e.g. `.opacity(0.5)` similar to `LeaderboardView`'s "Global Ranking" disabled style) and SHALL NOT respond to taps. The button MAY be accompanied by a short caption inviting the user to play that mode first; the caption is not strictly required.

#### Scenario: Disabled with no local entry
- **WHEN** the active filter bucket has no local score for the current player
- **THEN** the "Share my best" button is visible but disabled (muted opacity), taps do nothing, and no share sheet is presented

#### Scenario: Becomes enabled after first qualifying score
- **WHEN** the user posts their first score in a previously empty bucket and returns to the Leaderboard view filtered to that bucket
- **THEN** the "Share my best" button becomes enabled and tapping it shares that newly recorded best
