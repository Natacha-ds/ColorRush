## 1. Preparation

- [x] 1.1 Confirmed the seven `LeaderboardStore.shared.addScore(...)` call sites in `LevelGameView.swift`
- [x] 1.2 Confirmed `LeaderboardView` structure (single `selectedMistakeTolerance` segmented control)
- [x] 1.3 Confirmed `HomeView` uses `getOverallBestScore()` (parameter-less)

## 2. LeaderboardStore — keyed-by-(GameType,MistakeTolerance)

- [x] 2.1 Added `LeaderboardKey` struct (Hashable) with `storageKey: String` computed as `"leaderboard.\(gameType.rawValue).\(mistakeTolerance.rawValue)"`
- [x] 2.2 Replaced the three `@Published` arrays with a single `@Published var scoresByKey: [LeaderboardKey: [ScoreEntry]] = [:]`
- [x] 2.3 `loadScores()` now iterates `GameType.allCases × MistakeTolerance.allCases` to populate the dictionary
- [x] 2.4 `saveScores(_:forKey:)` unchanged in shape (still takes a string storage key)
- [x] 2.5 `addScore(_:gameType:mistakeTolerance:)` builds the `LeaderboardKey`, appends, sorts, prefix top 5, saves
- [x] 2.6 `getScores(gameType:mistakeTolerance:)` looks up `scoresByKey[key] ?? []`
- [x] 2.7 Removed unused `getBestScore(for:)` (confirmed dead by grep)
- [x] 2.8 `getOverallBestScore()` now flattens `scoresByKey.values` and picks the max
- [x] 2.9 `resetLeaderboard()` removes all six new keys and the three legacy keys (`leaderboard.easy/normal/hard`)
- [x] 2.10 Migration flag bumped to `"leaderboard.reset.done.v2"`

## 3. LevelGameView — pass gameType to addScore

- [x] 3.1 All seven `LeaderboardStore.shared.addScore(...)` call sites updated to pass `gameType: levelRun.gameType, mistakeTolerance: levelRun.mistakeTolerance` (single-line replace_all on the bare `for: levelRun.mistakeTolerance` argument)

## 4. LeaderboardView — second segmented control

- [x] 4.1 Added `@State private var selectedGameType: GameType = .colorOnly`
- [x] 4.2 Rendered a `GameType` segmented control above the existing `MistakeTolerance` control, matching the existing visual treatment (capsule with gradient stroke on the selected pill, 280 px wide, 36 px tall)
- [x] 4.3 Updated `getScores(...)` call to pass both `selectedGameType` and `selectedMistakeTolerance`
- [x] 4.4 Empty-state and score-row rendering unchanged

## 5. Validation

- [x] 5.1 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 5.2 Simulator (segregation): Color Only Easy run lands under Color Only / Easy only; other five tabs untouched
- [x] 5.3 Simulator (segregation): Color+Text Normal run lands under Color+Text / Normal; earlier entry preserved in its own bucket
- [x] 5.4 Simulator (migration): pre-v2 data wiped on first launch; all six tabs start empty
- [x] 5.5 Simulator regression: `HomeView`'s "best score" reflects the global maximum across buckets

## 6. Commit & archive

- [x] 6.1 Commit `39b54b2 fix: leaderboard keyed by (GameType, MistakeTolerance) (BUG-021)`
- [x] 6.2 `AUDIT_BUGS.md` status table updated (BUG-021 → ✅ Done) in the archive commit
- [x] 6.3 Archived via `/opsx:archive` to `2026-05-03-fix-bug-021-leaderboard-keyed-by-game-type-and-tolerance`
