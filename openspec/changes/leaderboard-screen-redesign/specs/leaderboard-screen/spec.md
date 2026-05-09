## ADDED Requirements

### Requirement: Leaderboard screen layout

The Leaderboard screen SHALL render, on a black background and matching Frame 10: a "RANKS" title at the top, a segmented mode selector (PURE / COLOR+WORD) below the title, a 3-chip difficulty selector (ROOKIE / PRO / INSANE) below the mode selector, a "YOU · RANK #X OF Y" pill below the filters when a Game Center rank is available for the current bucket, a ranked list of the top entries for the current bucket (or an empty state if neither GC nor local has any), a "Global Ranking" Game Center CTA below the list, and the existing custom bottom tab bar (which is already part of `MainTabView` and not the screen's responsibility).

#### Scenario: Default state on first open
- **WHEN** the user opens the Leaderboard tab for the first time after install
- **THEN** the mode selector defaults to PURE (`.colorOnly`), the difficulty defaults to ROOKIE (`.easy`), the screen shows the empty state for that bucket, and no rank pill is shown

#### Scenario: Mode change updates the displayed bucket
- **WHEN** the user taps the COLOR+WORD tab while difficulty is PRO
- **THEN** the displayed list updates to the entries for `(.colorAndText, .normal)` and any rank pill updates to that bucket's Game Center value (or hides if not yet fetched)

#### Scenario: Difficulty change updates the displayed bucket
- **WHEN** the user taps the INSANE chip while mode is PURE
- **THEN** the displayed list updates to the entries for `(.colorOnly, .hard)`

### Requirement: Brand labels

The Leaderboard screen SHALL display the following brand-styled labels for the existing enum cases, without modifying `GameType.displayName` or `MistakeTolerance.displayName`:
- `GameType.colorOnly` → "PURE"
- `GameType.colorAndText` → "COLOR+WORD"
- `MistakeTolerance.easy` → "ROOKIE"
- `MistakeTolerance.normal` → "PRO"
- `MistakeTolerance.hard` → "INSANE"

#### Scenario: PURE label visible for colorOnly
- **WHEN** the screen renders the mode tabs
- **THEN** the tab corresponding to `GameType.colorOnly` shows the text "PURE"

#### Scenario: ROOKIE label visible for easy
- **WHEN** the screen renders the difficulty chips
- **THEN** the chip corresponding to `MistakeTolerance.easy` shows the text "ROOKIE"

#### Scenario: Existing displayName not modified
- **WHEN** any other call site reads `GameType.colorOnly.displayName` after this change
- **THEN** it still returns the v1 string "🎨 Color Only" (unchanged)

### Requirement: Hybrid data source

The Leaderboard list SHALL be sourced from Game Center top entries when authenticated and the entries are available; otherwise it SHALL fall back to the local `LeaderboardStore` top-5 for the same bucket. This guarantees the screen is useful both for new / unauthenticated users (their own progress) and authenticated users (the global ranking).

#### Scenario: GC mode — authenticated with entries
- **WHEN** `gameCenter.isAuthenticated == true` AND `gameCenter.topEntries[currentKey]` is non-empty
- **THEN** the list renders those Game Center entries, each row showing the player's GC display name and formatted score, ordered by rank ascending

#### Scenario: Fallback mode — not authenticated
- **WHEN** `gameCenter.isAuthenticated == false`
- **THEN** the list renders `LeaderboardStore.getScores(for: currentKey)` ordered descending; each row shows rank and score, no display name (every entry is the user's own)

#### Scenario: Fallback mode — authenticated but GC fetch pending
- **WHEN** `gameCenter.isAuthenticated == true` AND `gameCenter.topEntries[currentKey]` is nil or empty AND a fetch is pending or failed
- **THEN** the list renders the local fallback (same as not-authenticated rendering) until GC entries become available

#### Scenario: Both empty
- **WHEN** neither `gameCenter.topEntries[currentKey]` nor `LeaderboardStore.getScores(for: currentKey)` has any entries
- **THEN** the empty state is rendered (no list, no rank pill source)

### Requirement: Score row rendering

The Leaderboard SHALL render each entry as a row with a rank number on the left, a player display (GC display name in GC mode; nothing in fallback mode), the score / formatted score on the right, and a crown icon (`crown.fill`, `Theme.Colors.pro`) on the rank #1 row. In GC mode, the row whose `isLocalPlayer == true` SHALL be highlighted with a `Theme.Colors.accent` (violet) border, lineWidth ≥ 2.

#### Scenario: First place has crown
- **WHEN** the list contains at least one entry for the current bucket
- **THEN** the rank #1 row shows a crown icon tinted in `Theme.Colors.pro`

#### Scenario: Local player row highlighted in GC mode
- **WHEN** the list is in GC mode and one entry has `isLocalPlayer == true`
- **THEN** that row renders with a violet (`Theme.Colors.accent`) border lineWidth ≥ 2 and shows the player's GC display name in the player slot

#### Scenario: No highlight in fallback mode
- **WHEN** the list is in fallback mode
- **THEN** no row carries a violet border (the highlight is meaningless when every row is the user's own score)

### Requirement: Empty state

The Leaderboard SHALL show a centered empty state when neither GC nor local has entries for the current bucket: a muted SF Symbol trophy icon, the text "No scores yet" in headline style, and a body-text invitation to play.

#### Scenario: Bucket has no scores
- **WHEN** both data sources resolve to empty arrays for the current selection
- **THEN** the empty state renders, the score list is hidden, and no rank pill is shown

### Requirement: Game Center rank pill

When the user is authenticated to Game Center and a global rank for the currently selected bucket has been fetched, the Leaderboard screen SHALL display a "YOU · RANK #X OF Y" pill above the score list. When either condition is not met, the pill SHALL be hidden.

#### Scenario: Authenticated and rank known
- **WHEN** `gameCenter.isAuthenticated` is true and `gameCenter.ranks[currentKey]` resolves
- **THEN** a pill renders showing "YOU · RANK #\(rank.rank) OF \(rank.totalPlayers)"

#### Scenario: Not authenticated
- **WHEN** `gameCenter.isAuthenticated` is false
- **THEN** the rank pill is hidden, regardless of any cached rank value

#### Scenario: Authenticated but rank not yet fetched
- **WHEN** `gameCenter.isAuthenticated` is true but `gameCenter.ranks[currentKey]` is nil
- **THEN** the rank pill is hidden until a fetch resolves

### Requirement: Refresh on filter and auth changes

The Leaderboard view SHALL trigger a `GameCenterService.refreshTopEntries(...)` and `refreshRank(...)` whenever it appears, whenever the selected mode or difficulty changes, and whenever `gameCenter.isAuthenticated` flips from false to true.

#### Scenario: Filter change refreshes data
- **WHEN** the user changes the selected mode or difficulty
- **THEN** the view triggers a fresh fetch of both the rank and the top entries for the new bucket

#### Scenario: Auth flip refreshes data
- **WHEN** the user signs into Game Center while the Leaderboard tab is visible
- **THEN** the view triggers a fresh fetch for the current bucket so the list can swap from local fallback to GC entries

### Requirement: Global Ranking CTA

The Leaderboard screen SHALL expose a "Global Ranking" call-to-action that opens the native Game Center leaderboard view scoped to the currently selected `(gameType, mistakeTolerance)` bucket. The CTA SHALL be enabled only when `gameCenter.isAuthenticated` is true; an auth-required helper text SHALL appear below the CTA when disabled.

#### Scenario: Authenticated tap opens Game Center
- **WHEN** the user is authenticated and taps "Global Ranking"
- **THEN** `GameCenterService.shared.presentLeaderboard(gameType:mistakeTolerance:)` is invoked with the current selection (existing behavior unchanged)

#### Scenario: Unauthenticated CTA disabled
- **WHEN** the user is not authenticated
- **THEN** the "Global Ranking" button is visually disabled and a helper text invites sign-in

### Requirement: Visual fidelity to design system

Every visual constant on the Leaderboard SHALL come from the design-system primitives. Hex literals, hard-coded font names, hard-coded spacing / radius values, and emoji used as visual icons (medals, globe, crown, mode/difficulty faces) SHALL NOT appear in `LeaderboardView.swift` after this change.

#### Scenario: No raw style literal in LeaderboardView
- **WHEN** auditing `LeaderboardView.swift` after this change
- **THEN** every color comes from `Theme.Colors.*`, every font from `Font.cr*`, every spacing/radius from `Theme.Spacing.*` / `Theme.Radius.*`, and no emoji acts as a visual layout icon

#### Scenario: Existing data services unchanged
- **WHEN** comparing this change's diff
- **THEN** `LeaderboardStore.swift`, `ScoreEntry.swift`, `LevelSystemModels.swift`, and `MainTabView.swift` are not modified (only `GameCenterService.swift` receives additive changes)
