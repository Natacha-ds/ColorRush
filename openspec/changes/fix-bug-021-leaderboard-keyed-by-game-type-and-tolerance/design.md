## Context

`LeaderboardStore` is a small singleton with three `@Published` arrays (`easyScores`, `normalScores`, `hardScores`), each persisted under a distinct `UserDefaults` key (`leaderboard.easy`, `.normal`, `.hard`). The class also has a one-time migration mechanism (`resetKey = "leaderboard.reset.done"`) that wipes the leaderboard on first launch.

The audit's BUG-021 finding is that this keying is too coarse: `GameType` is intentionally a meaningful difficulty axis, not just a UI label. Two `colorAndText` Normal runs are comparable; one `colorAndText` Normal and one `colorOnly` Normal are not. The leaderboard should reflect that.

`LeaderboardView` renders a single `MistakeTolerance` segmented control today. To distinguish modes we need a second segmented control for `GameType`. There are five other consumers in the codebase: seven `addScore(...)` call sites in `LevelGameView` (each in a different exit path) and a single `getOverallBestScore()` call in `HomeView`. None of them are inside the score-write hot path.

## Goals / Non-Goals

**Goals:**
- Make leaderboard storage and display key by `(GameType, MistakeTolerance)`.
- Migrate cleanly off the v1 schema using the existing reset-key pattern.
- Capture the leaderboard surface as its own spec capability so future work has a clean home.

**Non-Goals:**
- Cloud sync, GameCenter integration, or multiplayer leaderboards. Out of scope for this bug fix; the new `leaderboard` capability spec is forward-compatible with these.
- Reorganise the storage to a single backing JSON blob or `Codable` aggregate. Six small keys is fine and keeps the v2 migration trivial.
- Rebrand the segmented controls or change visual treatment beyond adding the second control.
- Fix BUG-022 navigation tweaks again — already shipped.

## Decisions

### New `leaderboard` capability instead of extending `level-gameplay`

**Decision:** introduce a new spec capability `leaderboard` and put the new requirement(s) there.

**Rationale:** the `level-gameplay` capability has grown to nine requirements covering the in-game session lifecycle. The leaderboard is a distinct domain (persistence + display, lives outside the gameplay loop, has its own consumers in `HomeView` and `LeaderboardView`). Future leaderboard features (cloud sync, weekly challenges, achievements) belong under a `leaderboard` capability, not a `level-gameplay` one. Capturing it now keeps the spec organised; this change introduces the capability with a single foundational requirement and future changes can extend it.

### Storage shape: dictionary keyed by `LeaderboardKey`, not six explicit arrays

**Decision:** replace the three `@Published` arrays with a single `@Published var scoresByKey: [LeaderboardKey: [ScoreEntry]]`, where `LeaderboardKey` is a small `Hashable` struct combining `gameType: GameType` and `mistakeTolerance: MistakeTolerance`.

**Rationale:** six explicit `@Published` arrays would mean writing six load / save / append bodies. The dictionary form lets the read/write code be parametric over the key, halving the duplication. SwiftUI's `@Published` works fine with `Dictionary` value types — view consumers re-render correctly when any key's value changes.

```swift
struct LeaderboardKey: Hashable {
  let gameType: GameType
  let mistakeTolerance: MistakeTolerance
  var storageKey: String {
    "leaderboard.\(gameType.rawValue).\(mistakeTolerance.rawValue)"
  }
}
```

`GameType.rawValue` is `colorOnly` / `colorAndText`; `MistakeTolerance.rawValue` is `easy` / `normal` / `hard`. The string keys end up self-documenting (`leaderboard.colorOnly.easy`).

### Migration: bump `resetKey` to `v2`, wipe both new and legacy keys

**Decision:** in `init()`, change the resetKey to `"leaderboard.reset.done.v2"`. On first launch with the new code, the previous v1 flag is missing, so `resetLeaderboard()` runs. Inside `resetLeaderboard()`, also explicitly remove the legacy keys (`leaderboard.easy`, `.normal`, `.hard`) so they don't linger as orphans.

**Rationale:** old data is keyed only by tolerance; we have no way to recover the `GameType` it came from. Trying to migrate-by-guessing would either bias the data toward one mode or split it unfairly. Pre-shipping (no real users), a clean wipe is honest and reversible (the v1 keys are explicitly cleared, so no orphan UserDefaults pollution remains).

If/when there are real users, this same pattern can be re-used: bump the version and migrate where possible. For BUG-021, wipe is acceptable.

### Keep `getOverallBestScore()` parameter-less

**Decision:** the `HomeView` call to `getOverallBestScore()` doesn't need parameters; the new implementation iterates `scoresByKey.values.flatMap { $0 }` and picks the max.

**Rationale:** the home-screen "best score" pill is a global summary across all buckets — no need to expose the bucketing to the caller. Keeps the public API minimal.

## Risks / Trade-offs

- **[Risk]** A future contributor adds a third `GameType` case but forgets to declare a new bucket in storage. → **Mitigation:** the dictionary-based storage doesn't need explicit declaration per bucket; new keys appear lazily on first write. The `LeaderboardView` segmented control iterates `GameType.allCases`, so it picks up new cases automatically.
- **[Risk]** A user playing a development build has scores they care about and they get wiped. → **Mitigation:** acknowledged. Tony has been testing with disposable scores; no data loss concern. Documented in proposal.
- **[Trade-off]** A Dictionary-backed `@Published` is a bit heavier than three separate arrays for SwiftUI to diff. The number of keys is bounded at 6, so the cost is invisible.

## Migration Plan

One-time `UserDefaults` migration on first launch with the new code:

1. `LeaderboardStore.init()` checks `leaderboard.reset.done.v2`. Missing on first launch → trigger `resetLeaderboard()`.
2. `resetLeaderboard()` removes:
   - All six new keys (covers re-runs of the migration if anything was already partially written).
   - All three legacy keys (`leaderboard.easy`, `.normal`, `.hard`) explicitly.
3. After reset, `userDefaults.set(true, forKey: "leaderboard.reset.done.v2")`.
4. The legacy v1 flag (`leaderboard.reset.done`) becomes inert and stays in `UserDefaults`. Could be cleaned up in a follow-up but harmless.

**Rollback:** `git revert` the implementation commit. The store reverts to three buckets. Players who already wrote scores on the new schema would see them disappear (because the old code reads from the legacy keys, which were cleared). Pre-shipping this is fine; post-shipping it would not be safe to rollback this way without writing a downgrade migration.
