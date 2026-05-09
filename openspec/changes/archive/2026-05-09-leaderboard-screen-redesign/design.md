## Context

`LeaderboardView` v1 is implemented inline with light-theme styling: purple-pink gradient title, white rounded segmented controls, white score rows with light gold/silver/bronze backgrounds for the top 3, emoji medal icons, white "Global Ranking" capsule that opens the native Game Center sheet. The view is fed exclusively by the **local** `LeaderboardStore` — a single-player history of the user's own best 5 scores per bucket.

The new design (Frame 10) shows a multi-player ranking with other players' usernames (alex_speed, noah.r, kira_88…) and the user's row highlighted. That is a Game Center surface, not a local one.

`GameCenterService` already owns:
- Authentication state (`isAuthenticated`, GKLocalPlayer.local lifecycle)
- Local-player rank fetching (`refreshRank` → `ranks: [LeaderboardKey: GameCenterRank]`)
- Score submission (`submitScore`)
- Leaderboard ID mapping for all 6 buckets
- Native sheet presentation (`presentLeaderboard`)

It uses `GKLeaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 1))` to fetch only the local player's entry. We can broaden the range (e.g., `length: 5`) to also receive the leaderboard's actual top entries, which is exactly what the redesign needs.

Constraints:
- Pure SwiftUI, no third-party.
- Must consume only design-system primitives in the view layer.
- Must not break offline / unauthenticated usage — the app must still show something useful when Game Center is unavailable.
- iOS 26+, GameKit Swift concurrency APIs already in use.

## Goals / Non-Goals

**Goals:**
- Migrate `LeaderboardView` to Frame 10 1:1.
- Extend `GameCenterService` with a top-entries fetch and a published cache, additive to the existing API.
- Render the global GC top-5 with each entry's GC display name when authenticated, including the local player's row visibly highlighted.
- Fall back to the local top-5 when Game Center is unavailable so the screen never appears empty for a player who has scores.
- Keep the existing "Global Ranking" CTA → native GC sheet behavior for the full ranking.

**Non-Goals:**
- Modify `LeaderboardStore`, `ScoreEntry`, `LevelSystemModels`, or `MainTabView`.
- Add a friends-only filter, a date filter, share buttons, or any other social affordance not on Frame 10.
- Show a "you-rank-N" insertion row when the player is below the displayed top-N (e.g., user rank 47 with only top-5 displayed). The "RANK #X OF Y" pill above the list already conveys this; we keep the list itself focused on the displayed slice.
- Refactor the v1 `GameType.displayName` / `MistakeTolerance.displayName` strings (still emoji-prefixed). They may be referenced from other call sites; out of scope.

## Decisions

### Decision 1: New `GameCenterEntry` value type + `topEntries` published cache

Add to `GameCenterService`:

```swift
struct GameCenterEntry: Equatable, Identifiable {
  let id: String          // gamePlayerID
  let rank: Int
  let displayName: String
  let formattedScore: String
  let isLocalPlayer: Bool
}

@Published private(set) var topEntries: [LeaderboardKey: [GameCenterEntry]] = [:]

func refreshTopEntries(
  for gameType: GameType,
  mistakeTolerance: MistakeTolerance,
  limit: Int = 5
) async { … }
```

The fetch reuses `GKLeaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: limit))`. The middle tuple element (the in-range entries array, currently discarded by `refreshRank`) is mapped to `[GameCenterEntry]` and stored under the bucket key. `isLocalPlayer` is derived by comparing `entry.player.gamePlayerID` to `GKLocalPlayer.local.gamePlayerID`.

**Why:** mirrors the existing `ranks` cache pattern; published value drives SwiftUI updates reactively; fetch is idempotent and side-effect-free.

**Alternative considered:** return entries directly from the method instead of caching. Rejected: every filter / auth change would re-fetch, and the SwiftUI view would need to manage async state plumbing. Cache + reactive published works better.

### Decision 2: Hybrid display strategy in `LeaderboardView`

Display logic, evaluated per render against the currently selected `(GameType, MistakeTolerance)` bucket:

1. If `gameCenter.topEntries[key]` is non-empty → render those entries (GC mode), highlight the row where `isLocalPlayer == true`.
2. Otherwise (not authenticated, fetch pending, fetch failed, or GC bucket empty) → render `LeaderboardStore.getScores(...)` (local mode). No row gets a username (every row is the user); rows show rank + score only, no highlight.
3. If both sources are empty → render the empty state.

**Why:** the user always sees something useful. New / unauthenticated players see their own progress; authenticated players see the actual global ranking.

**Alternative considered:** strict GC-only mode. Rejected: locks new players out of any feedback until they sign into Game Center, hostile UX.

### Decision 3: Local-player row highlight uses GC display name

When in GC mode, the local player's row shows their **GC display name** (per Tony) instead of a "YOU · BEST" pill. Visual differentiation is carried by a violet border (`Theme.Colors.accent`, lineWidth 2) around the row, so the user can still find themselves at a glance even if their name doesn't visually pop.

**Why:** matches the design's intent of showing real player identities; the violet border is the unambiguous "this is you" affordance.

**Alternative considered:** add a "YOU" badge next to the GC name. Rejected per Tony's direction — keep the pseudo, no extra badge.

### Decision 4: Refresh strategy

`refreshTopEntries` is called from `LeaderboardView` on:
- `.task` modifier when the view first appears
- `.onChange(of: selectedGameType)` and `.onChange(of: selectedMistakeTolerance)` (filter changes)
- `.onChange(of: gameCenter.isAuthenticated)` (sign-in / sign-out)

The existing `refreshRank` call is kept for the rank pill above the list — the two fetches are independent and the pill can resolve before / after the entries list.

**Why:** SwiftUI-idiomatic; matches the existing `refreshRank` pattern; no side effect from filter change other than a single network call.

### Decision 5: MODIFY the `gamecenter` capability "Native UI" requirement

The current spec says "The app SHALL NOT render its own custom global-leaderboard UI." That clause is incompatible with this change — we now render a custom subset of the global ranking inline. We MODIFY the requirement to:
- Keep the SHALL clause: native sheet via `presentLeaderboard(...)` is still the way to surface the full ranking.
- Replace the SHALL NOT with: "The app MAY render an in-app subset of the global ranking sourced from `GameCenterService.topEntries`. The full ranking SHALL still be reachable via the native sheet."

### Decision 6: Brand-label mapping stays private to `LeaderboardView.swift`

```swift
private extension GameType {
  var brandLabel: String { … }
}
private extension MistakeTolerance {
  var brandLabel: String { … }
}
```

Same rationale as before — visual-layer strings, easy to promote when Frames 2-3 need them.

### Decision 7: SF Symbols for crown / globe / trophy

`Image(systemName: "crown.fill")` for rank #1, `globe` for the Global Ranking CTA, `trophy` for the empty state. All tinted via `.foregroundStyle(...)` with design-system colors.

## Risks / Trade-offs

- **[Risk]** GameKit `loadEntries(for:timeScope:range:)` may be slow on first call → **Mitigation:** the published cache + reactive view means the screen renders immediately with the fallback (local top-5), then swaps in GC entries once the fetch resolves. Loading state is implicit.
- **[Risk]** GC display names may be very long and overflow the row → **Mitigation:** `lineLimit(1)` + `.truncationMode(.tail)` on the name `Text`.
- **[Risk]** `GameCenterEntry.id = gamePlayerID` may not be stable for friends with the same display name in old GC → acceptable for this design (no row identity reuse across fetches).
- **[Risk]** The "test" tab visit between filter changes may briefly show stale `topEntries[oldKey]` data while the new fetch is pending → **Mitigation:** the view reads `topEntries[currentKey]` (the *new* selection's bucket); if not present we show fallback. No stale data is rendered for the current filter.
- **[Trade-off]** Adding GC top-N fetch to `GameCenterService` increases its surface area → accepted: small additive change, parallels existing patterns.

## Migration Plan

1. Add `GameCenterEntry`, the `topEntries` published cache, and `refreshTopEntries(...)` to `GameCenterService.swift`.
2. Rewrite `LeaderboardView.swift` from scratch using design-system primitives, the hybrid display logic, and the brand-label private extensions.
3. Verify in `DesignSystemPreview` (no addition needed; Leaderboard is a screen-level preview only).
4. Build, run tests, run on simulator with both authenticated and unauthenticated states.

Rollback: revert `LeaderboardView.swift` and the `GameCenterService.swift` additions. No other file is touched.

## Open Questions

- Should we cache `topEntries` to disk for offline display? The current `LeaderboardStore` is on-device, but `topEntries` is in-memory only and resets on app relaunch → for now leave in-memory; if Tony notices a "flash of fallback then GC" effect that's annoying on relaunch we can persist.
- Should we display anything to indicate the list source switched (e.g., a small "Local" badge in fallback mode)? Not in Frame 10 — defer until Tony sees it in practice and has an opinion.
