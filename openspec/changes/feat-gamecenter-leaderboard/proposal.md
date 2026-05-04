## Why

Today the leaderboard is local-only: players see their own top-5 history per `(GameType × MistakeTolerance)` bucket, but cannot see how they rank against the rest of the playerbase. This caps the social retention loop. Game Center is Apple's built-in global ranking surface — every iOS player already has an identity (`GKLocalPlayer.local`), so we get a global leaderboard with zero account-management UX.

Tracking ticket: [TON-21 — Integrate Game Center leaderboard](https://linear.app/tonic-studio/issue/TON-21/integrate-game-center-leaderboard).

## What Changes

- Introduce a new `gamecenter` capability covering authentication, score submission, and leaderboard presentation.
- Add `GameCenterService` (`@MainActor` `ObservableObject` singleton) — naming consistent with `AdsService`, `StoreService`, `SpeechService`.
- Authenticate the local player at app launch via `GKLocalPlayer.local.authenticateHandler`. If sign-in is required, the system view controller is presented; otherwise the handler simply reports the auth state.
- On every successful end-of-run score save, mirror the score to the matching Game Center leaderboard. Game Center keeps only the player's best per leaderboard, so submission is fire-and-forget.
- Add a "Global Ranking" CTA in `LeaderboardView` that opens `GKGameCenterViewController` for the currently selected `(GameType, MistakeTolerance)` bucket. Disabled when the player is not authenticated.
- Enable the Game Center capability in the Xcode target so the `com.apple.developer.game-center` entitlement ships with the build.
- Use `GKLocalPlayer.local.alias` as the displayed nickname — no in-app prompt.

## Capabilities

### New Capabilities

- `gamecenter`: Game Center authentication, per-bucket score submission, and native leaderboard UI presentation. Six leaderboards — one per `(GameType × MistakeTolerance)` bucket — provisioned in App Store Connect.

### Modified Capabilities

- `leaderboard`: gains a single requirement — when a score is recorded locally, it is also forwarded to Game Center for global ranking. Local semantics (top-5 per bucket, `(GameType × MistakeTolerance)` keying, persistence under `leaderboard.<gameType>.<mistakeTolerance>` UserDefaults keys) remain unchanged.

## Impact

- **Code**: ~120 lines in a new `GameCenterService.swift`, ~30 lines of UI in `LeaderboardView` (the Global Ranking button + sheet presentation), 7 one-line additions at the `LeaderboardStore.addScore` call sites in `LevelGameView.swift`, and one line in `ColorGameApp.init()`.
- **Build**: no SPM dependency — `GameKit` is a system framework. Adds a Game Center entitlement.
- **Runtime / player behavior**:
  - Cold launch: Apple's Game Center welcome banner appears once if the player is signed in. If not signed in, a sign-in sheet appears once (skippable).
  - End-of-run: every score that lands in the local leaderboard is also submitted globally. Game Center deduplicates and keeps only the best.
  - `LeaderboardView`: a "Global Ranking" capsule button opens the native Game Center UI scoped to the currently selected bucket.
- **Persistence**: nothing new on disk. Local scores keep their existing `UserDefaults` storage; Game Center handles its own server-side state per Apple ID.
- **External dependencies**: GameKit (system); App Store Connect leaderboard provisioning (Tony, manual).
- **Tests**: no automated tests (none exist today). Manual coverage in the Tasks section, reusing the same Sandbox Tester accounts already created for the IAP work.
- **Production ship dependency**: Tony enables Game Center in App Store Connect and creates the six leaderboards with the IDs listed in `design.md`. With those done, no further code changes are required to flip from dev-test to production.
