## MODIFIED Requirements

### Requirement: Native Game Center UI is presented for the global ranking

The app SHALL present `GKGameCenterViewController` configured with `state: .leaderboards`, `leaderboardID` matching the currently selected `(GameType, MistakeTolerance)` bucket, `playerScope: .global`, and `timeScope: .allTime` whenever the user explicitly requests the full global ranking. The app MAY also render an in-app subset of the global ranking sourced from `GameCenterService.topEntries`; the full ranking SHALL still be reachable via the native sheet.

#### Scenario: Tap opens native sheet

- **WHEN** the player taps the in-app "Global Ranking" CTA on the Leaderboard while authenticated
- **THEN** `GameCenterService.presentLeaderboard(...)` invokes `GKGameCenterViewController` with `state: .leaderboards`, the matching `leaderboardID`, `playerScope: .global`, `timeScope: .allTime`, and the controller is presented over the app's root view controller

#### Scenario: Sheet is dismissed

- **WHEN** the player taps Done in the native Game Center sheet
- **THEN** `gameCenterViewControllerDidFinish` is invoked and the controller is dismissed

#### Scenario: In-app subset is allowed

- **WHEN** the in-app Leaderboard renders rows sourced from `GameCenterService.topEntries`
- **THEN** this is a permitted subset rendering and does not violate the requirement, provided the full ranking remains reachable via the native sheet

## ADDED Requirements

### Requirement: Top entries fetch for in-app display

`GameCenterService` SHALL expose a `refreshTopEntries(for:mistakeTolerance:limit:)` async method and a `@Published topEntries: [LeaderboardKey: [GameCenterEntry]]` cache. The fetch SHALL load up to `limit` global all-time entries for the matching leaderboard via the existing `GKLeaderboard.loadEntries(for:timeScope:range:)` API and SHALL update the cache reactively for SwiftUI consumers. The fetch SHALL be a no-op when not authenticated and SHALL log (not surface) errors.

#### Scenario: Fetch top 5 while authenticated

- **WHEN** `refreshTopEntries(for: .colorOnly, mistakeTolerance: .easy, limit: 5)` is called and the user is authenticated
- **THEN** the underlying GameKit call is `GKLeaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 5))`, the resolved entries are mapped to `[GameCenterEntry]` (one per returned `GKLeaderboard.Entry`), and stored under `topEntries[LeaderboardKey(.colorOnly, .easy)]`

#### Scenario: Local player flagged in fetched entries

- **WHEN** any returned entry's `player.gamePlayerID` matches `GKLocalPlayer.local.gamePlayerID`
- **THEN** that `GameCenterEntry` has `isLocalPlayer == true`; all other entries have `isLocalPlayer == false`

#### Scenario: Fetch while not authenticated

- **WHEN** `refreshTopEntries(...)` is invoked while `isAuthenticated == false`
- **THEN** the method returns silently without contacting Game Center, no error is surfaced, and the `topEntries` cache is unchanged for the requested key

#### Scenario: Fetch error is logged not surfaced

- **WHEN** the GameKit call throws an error
- **THEN** the error is logged via `print(...)` and the cache for the requested key is left unchanged (does not flip to nil; does not flip to empty)

#### Scenario: Empty leaderboard

- **WHEN** the leaderboard has no global entries (new game, fresh leaderboard ID)
- **THEN** `topEntries[key]` is set to an empty array (so SwiftUI consumers can distinguish "fetched, none" from "not yet fetched")
