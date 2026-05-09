## Why

The Leaderboard now lives inside the dark Liquid Glass tab bar shell shipped with `home-screen-redesign`, but its content is still v1 — light theme, white capsules, system fonts, emoji-driven UI — creating an immediate visual mismatch when the user switches tabs. The v1 view also shows only the **local** top-5 (the player's own best 5 scores), whereas Frame 10 shows a **global** ranked list with other players' Game Center usernames and the user's own row highlighted. Migrating Leaderboard now resolves both the visual dissonance and the misleading "leaderboard with no other players" semantic.

## What Changes

- Rebuild `LeaderboardView` from Frame 10's design: "RANKS" title, segmented mode tabs (PURE / COLOR+WORD), 3-chip difficulty filter (ROOKIE / PRO / INSANE), "YOU · RANK #X OF Y" pill, ranked list with crown for #1 and a violet-bordered highlight on the local player's row, "Global Ranking" CTA opening the native Game Center sheet.
- Extend `GameCenterService` with a new in-memory cache and fetch method that loads the top N entries for a `(GameType, MistakeTolerance)` bucket from Game Center via the existing `GKLeaderboard.loadEntries(...)` API, exposing each entry's rank, GC display name, formatted score, and whether it belongs to the local player.
- **Hybrid display strategy**: when the user is authenticated and the top entries are available, the list shows the global GC top-5 with each player's GC username; when the user is **not** authenticated (or the fetch is still pending / failed), the list falls back to the local top-5 (current v1 behavior preserved) — the offline experience stays useful.
- Map the existing `GameType` and `MistakeTolerance` enum cases to the new visual labels via private view-level extensions inside `LeaderboardView.swift`:
  - `colorOnly` → "PURE", `colorAndText` → "COLOR+WORD"
  - `easy` → "ROOKIE", `normal` → "PRO", `hard` → "INSANE"
- Drop emojis used as visual icons (🏆 in title, 🥇🥈🥉 medal icons, 🌍 globe, 👑 crown, 😊😐😤 difficulty faces, 🎨🎯 mode icons). Use SF Symbols (`crown.fill`, `globe`, `trophy`) tinted with design-system colors. The legacy `Crown.imageset` in the asset catalog is left untouched — it can be cleaned up in a later sweep.
- **No changes to the underlying game logic**: `LeaderboardStore`, `ScoreEntry`, `LeaderboardKey`, `GameType`, `MistakeTolerance`, and the rest of `GameCenterService`'s submission / authentication paths stay as-is. Only a read-only fetch method and a published cache are added to `GameCenterService`.

## Capabilities

### New Capabilities
- `leaderboard-screen`: View-layer contract for the redesigned Leaderboard surface — what it displays, how it filters, how it composes with the `LeaderboardStore` and `GameCenterService` services, and how it falls back when Game Center is unavailable.

### Modified Capabilities
- `gamecenter`: Adds a top-entries fetch capability (`GameCenterService.refreshTopEntries(...)` and a published `topEntries` cache) so the in-app Leaderboard can render Game Center rows directly. **MODIFIED** the existing "Native Game Center UI is presented for the global ranking" requirement: the app retains the native sheet for the full global ranking but is now also allowed to render an in-app subset of the top entries — the SHALL NOT clause is loosened.

## Impact

- **Modified**: `ColorGame/LeaderboardView.swift` (full rewrite of the body and `ScoreRowView`), `ColorGame/GameCenterService.swift` (additive: new `GameCenterEntry` type, `topEntries` published cache, `refreshTopEntries` method).
- **Unchanged**: `LeaderboardStore.swift`, `ScoreEntry.swift`, `LevelSystemModels.swift`, `MainTabView.swift` — none touched.
- **No new dependencies**: pure SwiftUI, uses the existing GameKit `GKLeaderboard.loadEntries(for:timeScope:range:)` already invoked by `refreshRank(...)`.
