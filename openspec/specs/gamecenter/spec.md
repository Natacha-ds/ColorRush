# gamecenter Specification

## Purpose
TBD - created by archiving change feat-gamecenter-leaderboard. Update Purpose after archive.
## Requirements
### Requirement: Game Center authentication is initiated at app launch

The app SHALL register `GKLocalPlayer.local.authenticateHandler` during the cold-start initialization of `GameCenterService`. The handler SHALL update the service's published `isAuthenticated` state on every invocation, and SHALL present the system sign-in view controller when the closure provides one.

#### Scenario: Player already signed in to Game Center

- **WHEN** the app launches and `GKLocalPlayer.local` is already authenticated at the OS level
- **THEN** the authenticate handler is invoked with no view controller and no error, `GameCenterService.shared.isAuthenticated` becomes `true`, and no sign-in UI is presented

#### Scenario: Player needs to sign in

- **WHEN** the app launches and Game Center is enabled at the OS level but the player is not signed in
- **THEN** the authenticate handler is invoked with a non-nil view controller, that controller is presented over the app's root view controller, and `isAuthenticated` flips to `true` once the player completes sign-in

#### Scenario: Game Center disabled at the OS level

- **WHEN** the player has restricted Game Center via Screen Time or has signed out at the OS level
- **THEN** the authenticate handler reports an error, `isAuthenticated` stays `false`, no sign-in sheet is forced, and the rest of the app keeps functioning with the local leaderboard only

### Requirement: Each `(GameType, MistakeTolerance)` bucket maps to a dedicated Game Center leaderboard

The app SHALL provide a deterministic mapping from a `(GameType, MistakeTolerance)` pair to a Game Center leaderboard ID. There SHALL be exactly six leaderboard IDs, mirroring the six local buckets. The mapping SHALL be exhaustive over `GameType.allCases × MistakeTolerance.allCases`.

#### Scenario: Color Only / Easy maps to its leaderboard

- **WHEN** `GameCenterService` resolves the leaderboard ID for `(gameType: .colorOnly, mistakeTolerance: .easy)`
- **THEN** the returned ID is `tonic.colorrush.leaderboard.coloronly_easy`

#### Scenario: Color + Text / Hard maps to its leaderboard

- **WHEN** `GameCenterService` resolves the leaderboard ID for `(gameType: .colorAndText, mistakeTolerance: .hard)`
- **THEN** the returned ID is `tonic.colorrush.leaderboard.colorandtext_hard`

### Requirement: Score submission is fire-and-forget and idempotent

`GameCenterService.submitScore(_:gameType:mistakeTolerance:)` SHALL submit the integer score to the matching leaderboard via `GKLeaderboard.submitScore(_:context:player:leaderboardIDs:)`. Submission SHALL NOT block the caller, SHALL NOT raise errors to the UI, and SHALL be safe to call repeatedly with the same or lower score because Game Center keeps only the player's best per leaderboard.

#### Scenario: A submitted score is registered globally

- **WHEN** the player finishes a Color Only / Easy run with score 150 while authenticated
- **THEN** `GameCenterService.submitScore(150, gameType: .colorOnly, mistakeTolerance: .easy)` returns immediately, and the value 150 is recorded against `tonic.colorrush.leaderboard.coloronly_easy` for the local player

#### Scenario: A lower subsequent submission is ignored by Game Center

- **WHEN** the player finishes another Color Only / Easy run with score 80 after previously submitting 150
- **THEN** the call still completes without error and the player's leaderboard entry remains 150

#### Scenario: Submission while not authenticated

- **WHEN** `submitScore` is called and `isAuthenticated == false`
- **THEN** the call returns silently without contacting Game Center, no error is surfaced, and the local leaderboard is unaffected

### Requirement: Native Game Center UI is presented for the global ranking

The app SHALL present `GKGameCenterViewController` configured with `state: .leaderboards`, `leaderboardID` matching the currently selected `(GameType, MistakeTolerance)` bucket, `playerScope: .global`, and `timeScope: .allTime`. The app SHALL NOT render its own custom global-leaderboard UI.

#### Scenario: Player opens the global ranking from `LeaderboardView`

- **WHEN** the player taps the "Global Ranking" CTA in `LeaderboardView` while authenticated and a bucket is selected
- **THEN** the system presents `GKGameCenterViewController` scoped to that bucket's leaderboard ID, the global player scope, and the all-time time scope

#### Scenario: Global ranking CTA is gated by authentication

- **WHEN** `isAuthenticated == false`
- **THEN** the "Global Ranking" CTA is rendered with a disabled (non-interactive, reduced-opacity) appearance and tapping it is a no-op

### Requirement: The player's global rank is fetched and exposed reactively

When the player is authenticated to Game Center, the app SHALL be able to refresh the local player's rank for any `(GameType, MistakeTolerance)` bucket via `GameCenterService.refreshRank(for:mistakeTolerance:)`. The result SHALL be exposed via a `@Published` collection keyed by bucket so SwiftUI views can render it reactively.

#### Scenario: Player has submitted at least one score in the bucket

- **WHEN** `refreshRank(for: .colorOnly, mistakeTolerance: .easy)` is called and the local player has previously submitted a score in that bucket
- **THEN** `ranks[LeaderboardKey(gameType: .colorOnly, mistakeTolerance: .easy)]` becomes non-nil and contains the player's `rank`, the bucket's `totalPlayers`, and the player's `formattedScore`

#### Scenario: Player has not submitted any score yet

- **WHEN** `refreshRank` is called for a bucket where the player has no entry
- **THEN** `ranks[<key>]` remains nil and no error is surfaced

#### Scenario: Refresh while not authenticated

- **WHEN** `refreshRank` is called and `isAuthenticated == false`
- **THEN** the call returns silently without contacting Game Center and the existing `ranks` state is unchanged

### Requirement: The leaderboard view shows the player's global rank inline

When the player is authenticated and a `(GameType, MistakeTolerance)` bucket is selected in `LeaderboardView`, the view SHALL render a compact rank pill showing the player's global position. The pill SHALL refresh when the player switches buckets, when the view appears, and when authentication completes.

#### Scenario: Player has a rank for the selected bucket

- **WHEN** the player opens `LeaderboardView` with a bucket selected and `ranks[<key>]` is non-nil
- **THEN** a capsule pill is rendered above the local top-5 list with the format "🌍 Rank #X of Y" where X is the player's rank and Y is the total player count

#### Scenario: Player has no rank yet for the selected bucket

- **WHEN** `ranks[<key>]` is nil — either because the refresh has not landed yet or because the player has not played that bucket
- **THEN** no rank pill is rendered (the view stays clean rather than showing a placeholder)

#### Scenario: Pill refreshes when the player changes the bucket

- **WHEN** the player taps a different `GameType` or `MistakeTolerance` chip in the selector
- **THEN** `GameCenterService.refreshRank` is invoked for the new bucket, and the pill updates to reflect the new bucket's rank when the data lands

### Requirement: Player identity uses the Game Center alias

The app SHALL NOT prompt the player for a custom in-app nickname for global ranking purposes. The displayed identity in the native Game Center view SHALL come from `GKLocalPlayer.local.alias`, rendered automatically by Apple inside `GKGameCenterViewController`.

#### Scenario: The leaderboard view shows the player's GC alias

- **WHEN** the player opens the global ranking and locates their own row
- **THEN** the row label shows `GKLocalPlayer.local.alias` (e.g., the alias the player chose at the OS level), not a value collected by ColorRush

