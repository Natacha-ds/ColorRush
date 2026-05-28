## ADDED Requirements

### Requirement: Share score pipeline

The app SHALL expose a single share entry point that, given a score, a `GameType`, a `MistakeTolerance`, and a source enum (`gameOver` or `leaderboard`), presents the iOS share sheet with both a localized text message and a rendered image badge attached. The same entry point SHALL be used by both `LevelGameOverView` and `LeaderboardView` so the message, image, and analytics stay consistent across screens.

#### Scenario: Share sheet is presented with text + image
- **WHEN** the user taps a share button anywhere the share pipeline is wired up
- **THEN** the iOS share sheet appears with the localized share message as the suggested text and the rendered badge image as the shared asset, ready to send to any installed destination (SMS, WhatsApp, Messages, Mail, X, Instagram, etc.)

#### Scenario: Pipeline is reused across screens
- **WHEN** both Game Over and Leaderboard share flows are inspected
- **THEN** they call the same share entry point with their respective `source`, `score`, `gameType`, and `mistakeTolerance` values, and the resulting share sheet produces an identical message format and badge style modulo the input values

### Requirement: Localized share message template

The share message SHALL be localized in `Localizable.xcstrings` with EN and FR translations, both marked `state: "translated"`. The message SHALL include the score (formatted with the device locale's number formatting) and the App Store URL `https://apps.apple.com/app/id6766084527`. No hard-coded English string SHALL appear in code for the share message.

#### Scenario: English message
- **WHEN** the device language is English and the player shares a score of 1420
- **THEN** the share message contains the score `1,420` (or `1420` depending on the chosen format) and the URL `https://apps.apple.com/app/id6766084527`, with English wording such as "I scored 1,420 points on ColorRush. Can you beat me? https://apps.apple.com/app/id6766084527"

#### Scenario: French message
- **WHEN** the device language is French and the player shares a score of 1420
- **THEN** the share message contains the score in French formatting (e.g. `1 420`) and the URL `https://apps.apple.com/app/id6766084527`, with French wording such as "J'ai marqué 1 420 points sur ColorRush. Tu peux faire mieux ? https://apps.apple.com/app/id6766084527"

#### Scenario: Localization catalog completeness
- **WHEN** the share message template key is inspected in `Localizable.xcstrings`
- **THEN** both `en` and `fr` entries exist with `state: "translated"` and the same number of replacement tokens

### Requirement: Score badge image

The app SHALL render a square image badge (logical size 1080x1080) from a SwiftUI view via `ImageRenderer` whenever the share pipeline is invoked. The badge SHALL display the ColorRush brand mark, the score in a hero font formatted via `Int.formatted()` (locale-aware), a single subtitle line combining the mode and difficulty brand labels, and a localized CTA at the bottom (`BEAT ME` / `FAIS MIEUX`). The mode and difficulty labels MUST be sourced from the same brand label mapping that `LeaderboardView` uses (PURE / COLOR+WORD, ROOKIE / PRO / MASTER); no parallel mapping SHALL be defined inside the badge view. Every visual constant on the badge SHALL come from the design-system primitives (`Theme.Colors.*`, `Theme.Gradient.*`, `Font.cr*`, `Theme.Spacing.*`, `Theme.Radius.*`). No raw hex literal, font name, or point spacing SHALL appear in the badge view body.

#### Scenario: Badge contains brand, formatted score, mode+difficulty subtitle, and CTA
- **WHEN** the badge is rendered for a score of 1420 in `(.colorAndText, .hard)` with the device set to English
- **THEN** the rendered image shows the ColorRush brand mark, the score `1,420` in the design-system hero font, a single subtitle line such as `COLOR+WORD · MASTER`, and the localized CTA `BEAT ME`

#### Scenario: Badge respects the design system
- **WHEN** the badge view body is audited
- **THEN** all colors come from `Theme.Colors.*` / `Theme.Gradient.*`, all fonts from `Font.cr*`, and all spacing/radius values from `Theme.Spacing.*` / `Theme.Radius.*`

#### Scenario: Badge reuses leaderboard brand labels
- **WHEN** the badge view body is audited
- **THEN** the mode and difficulty strings are sourced from the same brand label mapping used by `LeaderboardView` (no second source of truth), so renaming PURE / COLOR+WORD / ROOKIE / PRO / MASTER in one place flows through to the badge

#### Scenario: Badge renders at 2x scale
- **WHEN** the badge is rendered via `ImageRenderer`
- **THEN** the renderer's `scale` is 2 (final raster 2160x2160), unless a subsequent device test shows visible pixellation at 2x in which case scale is raised to 3

### Requirement: Share analytics event

Each tap on a share button SHALL emit one `share_tapped` event via `LogService.shared.log(_:_:)` with a payload containing:
- `source`: `"game_over"` or `"leaderboard"`
- `score`: the integer score
- `gameType`: `GameType.rawValue`
- `mistakeTolerance`: `MistakeTolerance.rawValue`

No additional events SHALL be emitted by the share pipeline (no completion tracking, no per-destination tracking).

#### Scenario: Event emitted on tap from Game Over
- **WHEN** the player taps the share button on `LevelGameOverView` with a total score of 1420 in `(.colorAndText, .hard)`
- **THEN** `LogService.shared.log("share_tapped", payload)` is called once with `payload` containing `source = "game_over"`, `score = 1420`, `gameType = "colorAndText"`, `mistakeTolerance = "hard"`

#### Scenario: Event emitted on tap from Leaderboard
- **WHEN** the player taps "Share my best" on `LeaderboardView` while filtered to `(.colorOnly, .easy)` with a local best of 820
- **THEN** `LogService.shared.log("share_tapped", payload)` is called once with `payload` containing `source = "leaderboard"`, `score = 820`, `gameType = "colorOnly"`, `mistakeTolerance = "easy"`

### Requirement: Accessibility labels on share buttons

Every share button wired to the share pipeline SHALL set an `.accessibilityLabel` describing the action to assistive technologies. The label SHALL be localized via `Localizable.xcstrings` (EN + FR), distinct from the visible button label so screen readers announce the action clearly even when only the icon is visually prominent.

#### Scenario: Game Over share button has accessibility label
- **WHEN** VoiceOver focuses the Game Over share button
- **THEN** the announced label is the localized "Share my run score" (or equivalent) and the trait reports a button

#### Scenario: Leaderboard share button has accessibility label
- **WHEN** VoiceOver focuses the Leaderboard "Share my best" button
- **THEN** the announced label is the localized "Share my best score for the current mode and difficulty" (or equivalent) and the trait reports a button

### Requirement: Deployment target compatibility

The share pipeline SHALL be implemented using only APIs available on iOS 17.0 (the current `IPHONEOS_DEPLOYMENT_TARGET`). `ShareLink` and `ImageRenderer` are both iOS 16+ and SHALL be used in preference to any UIKit bridge.

#### Scenario: No iOS 17.1+ or later API in the share code
- **WHEN** the share pipeline source files are audited
- **THEN** no API or syntax requires an iOS version higher than 17.0; no `@available(iOS X, *)` annotation appears for X greater than 17.0
