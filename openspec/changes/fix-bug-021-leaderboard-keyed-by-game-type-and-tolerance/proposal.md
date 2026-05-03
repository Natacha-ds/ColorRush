## Why

`LeaderboardStore` currently keys its top-5 leaderboards only by `MistakeTolerance` (Easy / Normal / Hard). The two game modes — `colorOnly` and `colorAndText` — have intentionally different scoring math (different points-per-round, different streak-bonus formula, different `requiredScore`), so the two modes' scores end up in the same Easy/Normal/Hard pile and cannot be honestly compared. A great Color+Text run can be beaten by a mediocre Color Only run (and vice-versa) just because the modes scale differently.

Pre-shipping concern for the App Store leaderboard surface — the top-5 list is meaningless to the player as long as it mixes incompatible scoring systems.

## What Changes

- Re-key `LeaderboardStore` storage by `(GameType, MistakeTolerance)`, giving six leaderboards instead of three.
- Replace `addScore(_:for:)` and `getScores(for:)` with two-parameter versions that take both `gameType` and `mistakeTolerance`. `getOverallBestScore()` keeps its current signature; only its body changes to iterate the new buckets.
- Update every caller in `LevelGameView` (seven `addScore` call sites) to pass `levelRun.gameType` alongside `levelRun.mistakeTolerance`.
- Update `LeaderboardView` to render a second segmented control for `GameType` (Color Only / Color + Text) above the existing `MistakeTolerance` control. Selecting (mode, difficulty) shows the top 5 for that bucket.
- One-time migration on first launch with the new code: bump the existing `leaderboard.reset.done` flag to `v2` so `resetLeaderboard()` runs again, clearing both the new and legacy `UserDefaults` keys. Pre-shipping, no real users affected.

## Capabilities

### New Capabilities

- `leaderboard`: persistence and display of best scores. Introduced as its own capability (rather than extending `level-gameplay`) because it is a distinct domain — it will likely grow to include cloud sync, multiplayer, achievements — and the persistence surface deserves first-class spec treatment now that it has non-trivial keying logic.

### Modified Capabilities

None.

## Impact

- **Code**: ~80 lines net across `LeaderboardStore.swift` (storage refactor + migration), `LevelGameView.swift` (seven call-site updates), `LeaderboardView.swift` (second segmented control), `HomeView.swift` (no surface change).
- **Build**: must remain green.
- **Runtime / player behavior**:
  - Leaderboard now has two segmented controls. Players can compare apples-to-apples within a `(mode, difficulty)` bucket.
  - On first launch with the new code, the existing leaderboard is wiped (single-time, transparent to the user — no real users today).
  - Home screen "best score" surface is unchanged on the API side; internally it iterates six buckets instead of three.
- **Persistence**: schema change. Old keys (`leaderboard.easy` / `.normal` / `.hard`) are deleted during migration. New keys are namespaced by mode (`leaderboard.colorOnly.easy`, etc.).
- **Tests**: no tests exist today.
- **External dependencies**: none.
