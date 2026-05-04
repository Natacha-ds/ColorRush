# leaderboard Specification

## Purpose
TBD - created by archiving change fix-bug-021-leaderboard-keyed-by-game-type-and-tolerance. Update Purpose after archive.
## Requirements
### Requirement: Leaderboards are keyed by game type and difficulty

The leaderboard surface SHALL maintain a separate top-5 list for each combination of `GameType` and `MistakeTolerance`. There SHALL be exactly six leaderboards: two game types (`colorOnly`, `colorAndText`) × three difficulties (`easy`, `normal`, `hard`). A run completed in one combination SHALL only affect that combination's leaderboard.

#### Scenario: A Color Only Easy run lands only in the Color Only Easy leaderboard

- **WHEN** the player completes a run with `gameType == .colorOnly` and `mistakeTolerance == .easy` and a final score of 100
- **THEN** the score is appended to the Color Only / Easy leaderboard, and the other five leaderboards are unchanged

#### Scenario: A Color+Text Normal run lands only in the Color+Text Normal leaderboard

- **WHEN** the player completes a run with `gameType == .colorAndText` and `mistakeTolerance == .normal` and a final score of 200
- **THEN** the score is appended to the Color+Text / Normal leaderboard, and the other five leaderboards are unchanged

#### Scenario: The leaderboard view exposes both axes

- **WHEN** the player opens the leaderboard
- **THEN** the view exposes two segmented controls — one for `GameType` (Color Only / Color + Text) and one for `MistakeTolerance` (Easy / Normal / Hard) — and shows the top 5 entries for the currently selected `(gameType, mistakeTolerance)` combination

#### Scenario: Overall best score covers all six buckets

- **WHEN** any caller invokes `LeaderboardStore.shared.getOverallBestScore()`
- **THEN** the returned value is the maximum score across all six leaderboards (not restricted to a single bucket)

### Requirement: Existing pre-v2 leaderboard data is wiped on first launch with the new schema

When the app launches for the first time with the v2 schema in place, any leaderboard data persisted under the legacy `MistakeTolerance`-only keys SHALL be cleared, and the migration SHALL be marked as done so it does not run twice.

#### Scenario: First launch after upgrade clears legacy data

- **WHEN** the app starts and the persistent flag `leaderboard.reset.done.v2` is not set
- **THEN** all `UserDefaults` entries under both the legacy keys (`leaderboard.easy`, `.normal`, `.hard`) and the new keys (`leaderboard.<gameType>.<tolerance>`) are removed, the in-memory `scoresByKey` is empty, and `leaderboard.reset.done.v2` is set so subsequent launches do not re-trigger the wipe

### Requirement: Locally-recorded scores are mirrored to Game Center

When `LeaderboardStore.addScore(_:gameType:mistakeTolerance:)` records a score in the local top-5 for a `(GameType, MistakeTolerance)` bucket, the score SHALL also be forwarded to `GameCenterService.shared.submitScore(_:gameType:mistakeTolerance:)` for global ranking. The local recording SHALL remain the source of truth for the in-app leaderboard view; the Game Center mirror is additive and SHALL NOT block, alter, or invalidate the local write.

#### Scenario: A successful run lands in both surfaces

- **WHEN** the player completes a run with `gameType == .colorOnly`, `mistakeTolerance == .normal`, and final score 220 while authenticated to Game Center
- **THEN** the score is appended to the local Color Only / Normal top-5 (existing behavior unchanged) AND `GameCenterService.shared.submitScore(220, gameType: .colorOnly, mistakeTolerance: .normal)` is invoked

#### Scenario: A successful run while Game Center is unavailable

- **WHEN** the player completes a run while `GameCenterService.shared.isAuthenticated == false` (sign-out, parental restriction, or first-launch sign-in still pending)
- **THEN** the score is still appended to the local top-5 with no behavioral change, and the Game Center mirror call returns silently

