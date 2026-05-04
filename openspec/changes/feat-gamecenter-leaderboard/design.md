## Context

ColorRush keeps a local leaderboard in `LeaderboardStore.swift`: top-5 per `(GameType × MistakeTolerance)` bucket, persisted in `UserDefaults` under keys shaped like `leaderboard.<gameType>.<mistakeTolerance>`. There are 6 buckets (`GameType` ∈ {`colorOnly`, `colorAndText`} × `MistakeTolerance` ∈ {`easy` = 5 lives, `normal` = 3 lives, `hard` = 1 life}). Each successful end-of-run calls `LeaderboardStore.shared.addScore(_:gameType:mistakeTolerance:)` from one of seven sites in `LevelGameView.swift`.

Game Center is Apple's native global leaderboard surface. It is part of GameKit (system framework, no SPM dep). Identity is the player's Game Center alias (`GKLocalPlayer.local.alias`), already unique per Apple ID and chosen at the OS level — no in-app onboarding required. A leaderboard accepts only the **best score per player**, so submission is idempotent.

## Goals / Non-Goals

**Goals:**
- Surface a global ranking view next to the existing local one.
- Mirror every locally-recorded score to Game Center, scoped to the matching bucket.
- Use Apple's stock `GKGameCenterViewController` UI — no custom global-leaderboard UI.
- Authenticate at app launch so the rest of the runtime can rely on the auth state without retry logic.
- Keep the change additive: the local leaderboard semantics, storage, and UI stay untouched.

**Non-Goals:**
- Custom-rendered global leaderboard inside `LeaderboardView`. Apple's view is good enough for v1 and avoids re-implementing scrolling, scoping (Friends / Global), pagination, and avatar rendering.
- Friend-graph features (challenge a friend, send invite). Out of scope for v1.
- Achievements (`GKAchievement`). Could come later; not part of this change.
- Custom score formatting (currency, time, etc.). Scores are integers, sort high-to-low.
- Server-side score moderation / anti-cheat. Game Center already enforces basic protections; we accept its model.

## Decisions

### One leaderboard per `(GameType × MistakeTolerance)` bucket

**Decision:** provision 6 Game Center leaderboards on App Store Connect, one per bucket. Bucket → leaderboard ID mapping:

| GameType | MistakeTolerance | Leaderboard ID |
|---|---|---|
| `colorOnly` | `easy` | `tonic.colorrush.leaderboard.coloronly_easy` |
| `colorOnly` | `normal` | `tonic.colorrush.leaderboard.coloronly_normal` |
| `colorOnly` | `hard` | `tonic.colorrush.leaderboard.coloronly_hard` |
| `colorAndText` | `easy` | `tonic.colorrush.leaderboard.colorandtext_easy` |
| `colorAndText` | `normal` | `tonic.colorrush.leaderboard.colorandtext_normal` |
| `colorAndText` | `hard` | `tonic.colorrush.leaderboard.colorandtext_hard` |

**Rationale:** the local leaderboard is already keyed by `(GameType, MistakeTolerance)` because comparing a 1-life Hard run to a 5-life Easy run is meaningless (different difficulty curves). The global ranking inherits the same logic — each bucket gets its own table. Six leaderboards is a one-time App Store Connect setup; the code maps `(GameType, MistakeTolerance)` → leaderboard ID via a single `switch`.

**Alternative considered:** one global leaderboard with bucket encoded as a leaderboard "context" tag. Rejected — Apple's filtering UX on context is non-existent; players would see incomparable scores mixed together.

### Authenticate at app launch via `GKLocalPlayer.local.authenticateHandler`

**Decision:** in `GameCenterService.init()`, set `GKLocalPlayer.local.authenticateHandler` immediately. The closure receives an optional `UIViewController` (the sign-in sheet) and an optional `Error`. If a view controller is passed, present it on the key window's root. Otherwise, set `isAuthenticated = (GKLocalPlayer.local.isAuthenticated)`.

**Rationale:** `authenticateHandler` is the canonical Game Center entry point. Setting it once at launch covers cold start, foreground-from-background, and Apple-internal re-auth events. Apple specifies that the closure may be invoked multiple times during the app's lifetime — we keep it long-lived.

**Alternative considered:** lazy auth on first leaderboard view tap. Rejected — submission also depends on auth, and we want to mirror scores to Game Center even before the user opens the leaderboard view. Auth at launch keeps the runtime simple.

### `submitScore` is fire-and-forget

**Decision:** `GameCenterService.submitScore` calls `GKLeaderboard.submitScore(_:context:player:leaderboardIDs:)` and ignores success/failure on the hot path. Errors are logged but not surfaced to the user.

**Rationale:** Game Center's submission is idempotent (only the best is kept) and the user's local leaderboard already gives instant feedback. Surfacing transient network errors would only add noise. Apple also queues submissions when offline — they replay on next online launch — so we do not need our own retry logic.

### Native `GKGameCenterViewController` for the global view

**Decision:** in `LeaderboardView`, the "Global Ranking" button presents `GKGameCenterViewController(leaderboardID: <id>, playerScope: .global, timeScope: .allTime)`. Wrap it in a `UIViewControllerRepresentable` for SwiftUI integration.

**Rationale:** Apple's stock view ships scrolling, paging, alias rendering, friend-vs-global toggle, time-scope picker, "Me" highlight, and game-center branding for free. A custom UI matching that quality would be ~500 lines of SwiftUI we do not need to write.

### Disable the global ranking button when not authenticated

**Decision:** the "Global Ranking" CTA is disabled (visual opacity + non-interactive) when `GameCenterService.shared.isAuthenticated == false`. The local leaderboard view stays fully functional.

**Rationale:** without auth, opening `GKGameCenterViewController` either shows an empty state or fails. Disabling the button is the cleanest signal that this surface is gated by Apple ID sign-in. Tony can later add a "sign in to Game Center" coaching message if it is a frequent dead-end.

### Lazy rank refresh on bucket selection (no prefetch)

**Decision:** the player's global rank is fetched on demand — at `LeaderboardView.onAppear`, when the bucket selector changes, and inside the `submitScore` completion handler — via `GameCenterService.refreshRank(for:mistakeTolerance:)`. The fetch uses `GKLeaderboard.loadLeaderboards(IDs:)` followed by `loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 1))`. The returned `localPlayerEntry` provides `rank` and `formattedScore`; the result tuple's `totalPlayerCount` provides the denominator for the displayed pill.

**Rationale:** prefetching all 6 buckets at launch would cost up to 6 network calls before the player even cares — most users only inspect one or two buckets per session. Lazy fetch is fast (sub-500 ms typical) and the SwiftUI re-render is automatic once `@Published var ranks` mutates. Refreshing inside `submitScore`'s completion ensures that the next time the player opens the leaderboard view post-game, the pill is already up-to-date even if the view's `onAppear` does not refire.

**Alternative considered:** prefetch all 6 ranks at authentication. Rejected — wastes bandwidth on buckets the player will not look at. We keep the per-session cost proportional to actual UI usage.

### Use `GKLocalPlayer.local.alias` as the displayed nickname

**Decision:** rely on the player's Game Center alias for global identity. No in-app nickname prompt.

**Rationale:** the alias is already unique per Apple ID, chosen by the player at the OS level, and rendered automatically inside `GKGameCenterViewController`. Adding our own nickname UX would duplicate Apple's, fragment the identity surface, and require us to handle uniqueness/profanity/storage we do not own.

## Risks / Trade-offs

- **[Risk]** The player has Game Center disabled at the OS level (`GKLocalPlayer.local.isAuthenticated` stays `false`). → **Mitigation:** the global ranking button is disabled, and the local leaderboard remains fully functional. We log a one-line auth state at launch for triage if a tester reports the button stays disabled.
- **[Risk]** A leaderboard ID typo in the `switch` returns `nil`, silently dropping submissions. → **Mitigation:** the `switch` is exhaustive over `GameType.allCases × MistakeTolerance.allCases` (6 cases — Swift enforces exhaustiveness). Manual sandbox validation step in tasks confirms each bucket lands a score.
- **[Risk]** A leaderboard is mis-configured on App Store Connect (wrong sort order, wrong score format). → **Mitigation:** dev test in sandbox catches it on the first submission. The 6 leaderboards share the same shape (Integer, sort High-to-low), so configuration drift across buckets is unlikely if Tony copies the first one.
- **[Risk]** GameKit's `submitScore` API silently no-ops if the user has restricted Game Center via Screen Time / parental controls. → **Mitigation:** out of our control; this is by design at the OS level. Local leaderboard still works.
- **[Trade-off]** Game Center adds the system welcome banner on launch. Some players find it intrusive. → Acceptable: Apple owns this UX surface and there is no opt-out for an integrated game.
- **[Trade-off]** Six separate leaderboards mean six App Store Connect entries to localize and maintain. → Acceptable cost for clean per-bucket ranking; the alternative (one merged table) is worse UX.

## Migration Plan

No runtime migration needed. The 6 Game Center leaderboards are empty on day one; players who installed v1 (no Game Center) and then upgrade get their next score submitted globally — their pre-upgrade local scores stay local-only (no backfill, since we do not store the full session history server-side). Acceptable: this is the *first* global ranking, so "rank from now" is a coherent semantic.

**Rollback:** `git revert` the implementation commit. The `GameCenterService` is gone, `LeaderboardStore.addScore` no longer mirrors. Local leaderboard is untouched. Players' Game Center scores stay on Apple's servers and reappear if the change is re-applied later.

## Open Questions

- Should the "Global Ranking" button live inside `LeaderboardView` or also on `HomeView`? The proposal targets `LeaderboardView`. If post-ship feedback shows discoverability is an issue, we revisit.
- Localization of the leaderboard display names is part of Tony's manual setup (App Store Connect supports per-locale strings). v1 ships EN + FR + ES + DE + PT-BR — same locales as the IAP — for consistency.
