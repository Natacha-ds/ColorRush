## ADDED Requirements

### Requirement: Locally-recorded scores are mirrored to Game Center

When `LeaderboardStore.addScore(_:gameType:mistakeTolerance:)` records a score in the local top-5 for a `(GameType, MistakeTolerance)` bucket, the score SHALL also be forwarded to `GameCenterService.shared.submitScore(_:gameType:mistakeTolerance:)` for global ranking. The local recording SHALL remain the source of truth for the in-app leaderboard view; the Game Center mirror is additive and SHALL NOT block, alter, or invalidate the local write.

#### Scenario: A successful run lands in both surfaces

- **WHEN** the player completes a run with `gameType == .colorOnly`, `mistakeTolerance == .normal`, and final score 220 while authenticated to Game Center
- **THEN** the score is appended to the local Color Only / Normal top-5 (existing behavior unchanged) AND `GameCenterService.shared.submitScore(220, gameType: .colorOnly, mistakeTolerance: .normal)` is invoked

#### Scenario: A successful run while Game Center is unavailable

- **WHEN** the player completes a run while `GameCenterService.shared.isAuthenticated == false` (sign-out, parental restriction, or first-launch sign-in still pending)
- **THEN** the score is still appended to the local top-5 with no behavioral change, and the Game Center mirror call returns silently
