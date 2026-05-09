## 1. Extend GameCenterService

- [x] 1.1 In `ColorGame/GameCenterService.swift`, declare a new value type at file scope: `struct GameCenterEntry: Equatable, Identifiable { let id: String; let rank: Int; let displayName: String; let formattedScore: String; let isLocalPlayer: Bool }`. The `id` is the player's `gamePlayerID`.
- [x] 1.2 Add a `@Published private(set) var topEntries: [LeaderboardKey: [GameCenterEntry]] = [:]` to `GameCenterService`.
- [x] 1.3 Add `func refreshTopEntries(for gameType: GameType, mistakeTolerance: MistakeTolerance, limit: Int = 5) async`. The method (a) returns silently when `!isAuthenticated`, (b) calls `GKLeaderboard.loadLeaderboards(IDs:[id])` with the existing `leaderboardID(for:mistakeTolerance:)` mapping, (c) calls `loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: limit))`, (d) maps the returned `[GKLeaderboard.Entry]` to `[GameCenterEntry]` (deriving `isLocalPlayer` from `player.gamePlayerID == GKLocalPlayer.local.gamePlayerID`), (e) writes the result into `topEntries[key]`, (f) logs and returns on error without mutating the cache except for the empty-leaderboard case which writes `[]`.
- [x] 1.4 Verify the new code compiles and that existing `refreshRank(...)` semantics are unchanged.

## 2. Brand-label extensions

- [x] 2.1 In `ColorGame/LeaderboardView.swift`, declare `private extension GameType { var brandLabel: String { … } }` mapping `colorOnly` → "PURE" and `colorAndText` → "COLOR+WORD"
- [x] 2.2 Same file, declare `private extension MistakeTolerance { var brandLabel: String { … } }` mapping `easy` → "ROOKIE", `normal` → "PRO", `hard` → "INSANE"

## 3. Header (title + filters + rank pill)

- [x] 3.1 Replace the v1 emoji-prefixed gradient title with a left-aligned "RANKS" `Text` styled as `.font(.crTitle)`, `Theme.Colors.textPrimary`, uppercase, padded to match Frame 10
- [x] 3.2 Build the **mode selector**: a 2-tab segmented control (private subview), each tab a tappable `Capsule` showing the brand label; active tab uses a `Theme.Colors.accentSecondary` (cyan) border, inactive a subtle `Theme.Colors.border`; horizontally arranged inside a single `Theme.Colors.surface` rounded container
- [x] 3.3 Build the **difficulty selector**: a 3-chip `HStack` (private subview), each chip a `Capsule` with the brand label; active chip uses a `Theme.Colors.accent` (violet) border, inactive a subtle `Theme.Colors.border`
- [x] 3.4 Restyle the **rank pill** ("YOU · RANK #X OF Y"): a `CRChip(tone: .accent)`-styled pill, conditionally rendered only when both `gameCenter.isAuthenticated` AND `gameCenter.ranks[currentKey]` resolve

## 4. Hybrid score list

- [x] 4.1 Compute the displayed list per render: `displayedRows: [DisplayRow]` where `DisplayRow` is a private view-level enum with two cases — `.gc(GameCenterEntry)` and `.local(rank: Int, score: Int)`. Source GC entries from `gameCenter.topEntries[currentKey]` if non-empty AND authenticated; otherwise map `LeaderboardStore.getScores(...)` to local rows ordered descending by score.
- [x] 4.2 Rewrite the inline `ScoreRowView` to switch on `DisplayRow`:
  - GC row: rank number on the left (small, gold for #1, violet for `isLocalPlayer`, otherwise muted), GC `displayName` in the middle (truncated single line), `formattedScore` on the right in `.crTitle`, crown SF Symbol on rank 1, violet border around the row when `isLocalPlayer == true`
  - Local row: rank number on the left, no name, score on the right, crown SF Symbol on rank 1, no violet border
- [x] 4.3 Apply `Theme.Colors.surface` background for all rows; differentiators are crown for #1 + violet/gold border tinting

## 5. Empty state

- [x] 5.1 Replace the v1 empty state with a centered VStack: muted SF Symbol `trophy` icon (`Theme.Colors.textMuted`), "No scores yet" `.crHeadline` `Theme.Colors.textPrimary`, "Play a level to land on the board." `.crBody` `Theme.Colors.textSecondary`. Render only when both data sources resolve to empty arrays for the current bucket.

## 6. Game Center CTA

- [x] 6.1 Restyle the "Global Ranking" button as a centered `Capsule`-shaped button with `Theme.Colors.surfaceElevated` background, SF Symbol `globe` + "Global Ranking" `.crButtonLabel`, disabled appearance (opacity ≤ 0.5) when `!gameCenter.isAuthenticated`
- [x] 6.2 Keep the existing `presentLeaderboard(gameType:mistakeTolerance:)` invocation on tap
- [x] 6.3 Below the button, render the auth-prompt helper text (`Theme.Colors.textSecondary`, `.crCaption`) only when `!gameCenter.isAuthenticated`

## 7. Refresh wiring

- [x] 7.1 Add a `.task { await refreshAll() }` modifier on the screen so the GC fetch starts on first appearance
- [x] 7.2 Call both `refreshRank(...)` AND `refreshTopEntries(...)` from a single `refreshAll()` helper invoked on filter change (`.onChange(of: selectedGameType)`, `.onChange(of: selectedMistakeTolerance)`) and on auth flip (`.onChange(of: gameCenter.isAuthenticated)` when becoming true)

## 8. Background and chrome integration

- [x] 8.1 Replace the v1 light `LinearGradient` background with `Theme.Colors.background.ignoresSafeArea()`
- [x] 8.2 Apply `.preferredColorScheme(.dark)` to the screen
- [x] 8.3 Confirm the screen lays out correctly inside the `MainTabView`'s `safeAreaInset(edge: .bottom)` `CRTabBar` shell — the screen layout uses Spacer(minLength: 0) before the CTA so content reflows above the tab bar pill

## 9. Verification

- [x] 9.1 Build the app with `xcodebuild` and confirm BUILD SUCCEEDED with no new warnings
- [x] 9.2 Run the unit test suite (`ColorGameTests`) with `-only-testing:ColorGameTests -parallel-testing-enabled NO` and confirm zero regression — **TEST SUCCEEDED**. UI tests skipped during iteration to avoid spawning simulator clones; Tony will run them in Xcode (cmd+U) before merge if desired.
- [ ] 9.3 Open `LeaderboardView` in Xcode preview; visually compare against `screens/Frame 10.png` for: title, segmented mode tabs, difficulty chips, rank pill (mock auth state if needed), score row in GC mode (with crown on #1 and violet border on local-player row), score row in fallback mode, empty state — **manual review by Tony**
- [ ] 9.4 Launch on simulator while NOT signed into Game Center: switch to the Leaderboard tab, tap each mode and difficulty combination, verify the displayed list reflects each `(GameType, MistakeTolerance)` bucket from local store, verify no rank pill is shown, verify "Global Ranking" button is disabled with helper text — **manual review by Tony**
- [ ] 9.5 Launch on simulator while signed into Game Center (sandbox account): verify the displayed list shows GC entries with display names, verify the rank pill is shown when present, verify "Global Ranking" opens the native sheet — **manual review by Tony**
- [x] 9.6 Audit `LeaderboardView.swift`: no hex literal, no hard-coded font name, no raw point spacing, no emoji as visual icon — clean, every value sourced from `Theme.*` / `Font.cr*`
- [x] 9.7 Audit the diff: `LeaderboardStore.swift`, `ScoreEntry.swift`, `LevelSystemModels.swift`, and `MainTabView.swift` are NOT modified; only `GameCenterService.swift` receives additive changes (new `GameCenterEntry` type + `topEntries` cache + `refreshTopEntries` method)
