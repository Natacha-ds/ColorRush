## Why

ColorRush has no built-in way for players to share their scores. Word-of-mouth and social shares are the primary organic growth lever for a casual free-to-play iOS game, so leaving the share moment off the table caps the app's discoverability. Two emotional high points are wasted today: the end of a run (Game Over) and the moment a player views their personal best on the Leaderboard.

## What Changes

- Add a share affordance on `LevelGameOverView` that lets the player share the run's total score from the screen they just hit.
- Add a "Share my best" affordance at the top of `LeaderboardView` that shares the local player's best score for the currently selected (`GameType`, `MistakeTolerance`) bucket.
- Build a single shared share pipeline that produces:
  - A localized text message containing the score and the App Store URL `https://apps.apple.com/app/id6766084527`.
  - A square image badge rendered from a SwiftUI view via `ImageRenderer`, used as the share preview and attached to the share payload so it lands in WhatsApp, Messages, X, Instagram Stories, Mail, etc.
- Track each share tap with a `share_tapped` `LogService` event, including score, source screen, game type, mistake tolerance.
- Add EN + FR strings to `Localizable.xcstrings` for every new user-facing string and the share message template.

## Capabilities

### New Capabilities
- `share-score`: end-to-end pipeline for sharing a ColorRush score from the app via the iOS share sheet, including badge image generation, message templating, and analytics.

### Modified Capabilities
- `game-over-screen`: adds a secondary share button to the Game Over layout.
- `leaderboard-screen`: adds a "Share my best" button above the ranked list, tied to the currently selected filter.

## Impact

- Code:
  - `ColorGame/LevelGameView.swift` — `LevelGameOverView` body (insert share button).
  - `ColorGame/LeaderboardView.swift` — header section above the ranked list (insert "Share my best" button), wired to `HighScoreStore` for the local best in the active bucket.
  - New `ColorGame/Sharing/ShareScoreService.swift` (or similar location alongside existing services) wrapping the `Transferable` payload + `ImageRenderer` flow.
  - New SwiftUI view for the badge layout (e.g., `ColorGame/Sharing/ShareableScoreBadge.swift`).
  - `ColorGame/Localizable.xcstrings` — new keys for button label, badge text, share message template (EN + FR).
- Dependencies: none (uses SwiftUI `ShareLink` + `ImageRenderer`, both iOS 16+; deployment target is now iOS 17).
- Analytics: one new event name `share_tapped` consumed by the existing `LogService` pipeline.
- No Game Center, ads, IAP, or gameplay logic is touched.
