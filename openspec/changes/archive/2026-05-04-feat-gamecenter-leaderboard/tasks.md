## 1. Manual setup (Tony)

- [x] 1.1 In **App Store Connect → ColorRush → Services → Game Center**, enable Game Center for the app
- [x] 1.2 In Game Center, create six **leaderboards** with these IDs and shapes:
  - `tonic.colorrush.leaderboard.coloronly_easy` — Reference Name: "Color Only — 5 Lives" — Score Format: Integer — Sort Order: High to Low
  - `tonic.colorrush.leaderboard.coloronly_normal` — Reference Name: "Color Only — 3 Lives" — Score Format: Integer — Sort Order: High to Low
  - `tonic.colorrush.leaderboard.coloronly_hard` — Reference Name: "Color Only — 1 Life" — Score Format: Integer — Sort Order: High to Low
  - `tonic.colorrush.leaderboard.colorandtext_easy` — Reference Name: "Color + Text — 5 Lives" — Score Format: Integer — Sort Order: High to Low
  - `tonic.colorrush.leaderboard.colorandtext_normal` — Reference Name: "Color + Text — 3 Lives" — Score Format: Integer — Sort Order: High to Low
  - `tonic.colorrush.leaderboard.colorandtext_hard` — Reference Name: "Color + Text — 1 Life" — Score Format: Integer — Sort Order: High to Low
- [ ] 1.3 For each leaderboard, add localized display names in EN, FR, ES, DE, PT-BR (same locales as the IAP). Suggested EN copy already in 1.2; provide equivalents in the other four locales
- [ ] 1.4 Upload a 1024×1024 leaderboard icon if Apple requires one (a reuse of the app icon is fine)
- [x] 1.5 In **Xcode → Signing & Capabilities** for the `ColorGame` target, add the **Game Center** capability (this writes `com.apple.developer.game-center` to the entitlements file)
- [x] 1.6 Verify the existing Sandbox Tester accounts created during the IAP work also work for Game Center — same account is used. If sign-out / sign-in is needed in **Settings → Game Center** on the test device, do it once per tester

## 2. GameCenterService implementation

- [x] 2.1 Create `ColorGame/GameCenterService.swift` with `import Combine, Foundation, GameKit, UIKit`
- [x] 2.2 `@MainActor final class GameCenterService: ObservableObject` shared singleton
- [x] 2.3 `@Published private(set) var isAuthenticated: Bool = false`
- [x] 2.4 Private `static func leaderboardID(for gameType: GameType, mistakeTolerance: MistakeTolerance) -> String` with an exhaustive `switch` returning the six IDs from task 1.2
- [x] 2.5 `init()` sets `GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in ... }`. If `viewController != nil`, present it on the key window's root. Always update `self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated` at the end of the closure. Log `error` if non-nil
- [x] 2.6 Helper `private func presentSignIn(_ viewController: UIViewController)` that walks the connected scenes to find the key window's root and presents the sign-in sheet from the topmost VC (mirroring the chain walk used in `AdsService.currentRootViewController()`)
- [x] 2.7 `func submitScore(_ score: Int, gameType: GameType, mistakeTolerance: MistakeTolerance)`:
  - Early-return silently when `!isAuthenticated`
  - Resolve the leaderboard ID via 2.4
  - Call `GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [<id>]) { error in ... }`
  - Log non-nil errors, do not propagate
- [x] 2.8 `func presentLeaderboard(gameType: GameType, mistakeTolerance: MistakeTolerance)`:
  - Resolve the leaderboard ID via 2.4
  - Instantiate `GKGameCenterViewController(leaderboardID: <id>, playerScope: .global, timeScope: .allTime)`
  - Set `gameCenterDelegate = self` so the dismiss-button callback works
  - Present from the key window's topmost VC (same helper as 2.6)
- [x] 2.9 Conform `GameCenterService` to `GKGameCenterControllerDelegate` and implement `gameCenterViewControllerDidFinish(_:)` to dismiss the view controller

## 3. App-level wiring

- [x] 3.1 In `ColorGameApp.init()`, append `_ = GameCenterService.shared` after the existing `_ = StoreService.shared` line so the singleton's lazy init kicks off the authenticate handler at app launch

## 4. Score submission hook

- [x] 4.1 Identify all sites in `ColorGame/LevelGameView.swift` that call `LeaderboardStore.shared.addScore(_:gameType:mistakeTolerance:)` (currently 7 sites). Right after each call, invoke `GameCenterService.shared.submitScore(score, gameType: gameType, mistakeTolerance: mistakeTolerance)` with the same triple
- [x] 4.2 Verify the score variable in scope at each call site matches the integer being saved locally — no transformation should be applied between the two calls

## 5. LeaderboardView UI

- [x] 5.1 Add `@StateObject private var gameCenter = GameCenterService.shared` to `LeaderboardView`
- [x] 5.2 Below the local top-5 list, render a "🌍 Global Ranking" capsule button styled to match the existing leaderboard CTAs (white background, subtle shadow, gradient stroke). The button title and font size should align with the bucket-selector visuals
- [x] 5.3 The button is enabled only when `gameCenter.isAuthenticated`. When disabled: opacity 0.5, non-interactive, and tooltip-equivalent caption underneath: "Sign in to Game Center to see the global ranking"
- [x] 5.4 On tap, call `gameCenter.presentLeaderboard(gameType: selectedGameType, mistakeTolerance: selectedMistakeTolerance)` so the native view opens scoped to the current bucket selection

## 6. Validation

- [x] 6.1 `xcodebuild -project ColorGame.xcodeproj -scheme ColorGame -destination 'generic/platform=iOS Simulator' build` returns `BUILD SUCCEEDED`
- [x] 6.2 Simulator with a sandbox tester signed into Game Center (Settings → Game Center → sandbox account): launch the app → Apple's Game Center welcome banner appears → `isAuthenticated` flips to `true` (verify via a temporary `print` in `init` if needed)
- [x] 6.3 Play a Color Only / Easy run, complete it with a non-zero score → score appears in the local top-5. Tap "🌍 Global Ranking" in `LeaderboardView` → native UI opens and shows the freshly submitted score under "Me"
- [x] 6.4 Run a SECOND game in the same bucket with a HIGHER score → global view reflects the higher score; running with a LOWER score → global view stays at the previous high
- [x] 6.5 Run one game in each of the six buckets → each leaderboard shows the corresponding score, and switching buckets in `LeaderboardView` re-opens the GC view scoped to that bucket
- [x] 6.6 Sign out from Game Center on the device → relaunch app → `isAuthenticated == false`, the "🌍 Global Ranking" CTA is disabled and shows the sign-in caption, the local top-5 list still works
- [x] 6.7 Sign back in → relaunch → CTA re-enables; submit a new score → it lands globally as expected

## 8. Player rank fetch & inline display

- [x] 8.1 In `GameCenterService`, define `struct GameCenterRank: Equatable { let rank: Int; let totalPlayers: Int; let formattedScore: String }`
- [x] 8.2 Add `@Published private(set) var ranks: [LeaderboardKey: GameCenterRank] = [:]`. Reuse the `LeaderboardKey` type already defined in `LeaderboardStore.swift`
- [x] 8.3 Implement `func refreshRank(for gameType: GameType, mistakeTolerance: MistakeTolerance) async`:
  - early-return when `!isAuthenticated`
  - resolve the leaderboard ID via the existing `Self.leaderboardID(for:mistakeTolerance:)`
  - call `GKLeaderboard.loadLeaderboards(IDs: [<id>])`
  - call `leaderboard.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 1))`
  - on success: if `localPlayerEntry` is non-nil, set `ranks[key] = GameCenterRank(...)`; else set `ranks[key] = nil`
  - on error: log silently, do not propagate
- [x] 8.4 Inside `submitScore`'s completion handler, on success kick off `Task { await self.refreshRank(for: gameType, mistakeTolerance: mistakeTolerance) }` so the pill is current next time the leaderboard view opens
- [x] 8.5 In `LeaderboardView`, render a compact rank pill above the scores list when `gameCenter.isAuthenticated && gameCenter.ranks[<currentKey>] != nil`. Style: capsule, white background, gradient stroke (blue → purple) matching the "Global Ranking" CTA, text "🌍 Rank #X of Y"
- [x] 8.6 Trigger `await gameCenter.refreshRank(for: selectedGameType, mistakeTolerance: selectedMistakeTolerance)` from `LeaderboardView.onAppear`
- [x] 8.7 Trigger the same refresh from `.onChange(of: selectedGameType)` and `.onChange(of: selectedMistakeTolerance)`
- [x] 8.8 Trigger the same refresh from `.onChange(of: gameCenter.isAuthenticated)` when the value flips to `true`, so cold-start auth that resolves after the view is on-screen still populates the pill
- [x] 8.9 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 8.10 Sandbox validation: open `LeaderboardView` post-submission → pill appears showing "🌍 Rank #1 of 1" (you are the only sandbox player). Switch buckets → the pill disappears for unplayed buckets and reappears with the correct rank when navigating back

## 7. Commit & archive

- [x] 7.1 Commit with message `feat: ship Game Center leaderboard integration (feat-gamecenter-leaderboard)`
- [x] 7.2 No `AUDIT_BUGS.md` entry — feature
- [x] 7.3 Archive via `/opsx:archive feat-gamecenter-leaderboard`
- [x] 7.4 Update Linear ticket TON-21 to `Done` and link the merged commit
