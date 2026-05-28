## 1. Localization

- [x] 1.1 Add `share.button.label` key to `Localizable.xcstrings` with EN `SHARE` and FR `PARTAGER`, both `state: "translated"`.
- [x] 1.2 Add `share.leaderboard.button.label` key with EN `SHARE MY BEST` and FR `MON RECORD`, both `state: "translated"`.
- [x] 1.3 Add `share.message.template` key to `Localizable.xcstrings` with EN `I scored %lld points on ColorRush. Can you beat me? %@` and FR `J'ai marqué %lld points sur ColorRush. Tu peux faire mieux ? %@`, both `state: "translated"`. Use positional tokens (`%1$lld`, `%2$@`) if FR ordering diverges.
- [x] 1.4 Add badge keys: `share.badge.cta` (EN `BEAT ME` / FR `FAIS MIEUX`) and `share.badge.subtitle.template` (EN `%@ · %@` / FR `%@ · %@` — placeholders are the localized mode and difficulty labels reused from the leaderboard brand mapping). Both `state: "translated"`.

## 2. Share badge view

- [x] 2.1 Create `ColorGame/Sharing/ShareableScoreBadge.swift` defining a SwiftUI `View` with parameters `score: Int`, `gameType: GameType`, `mistakeTolerance: MistakeTolerance`.
- [x] 2.2 Lay out the badge as a square (logical 1080x1080) on a brand gradient background sourced from `Theme.Gradient.*`, with the ColorRush brand mark at the top, the score in `.crHero` (or equivalent design-system hero font) in the center using `Int.formatted()` for locale-aware grouping, a single subtitle line below the score combining the mode label and difficulty label via `share.badge.subtitle.template` (e.g. `PURE · ROOKIE`), and the localized `BEAT ME` / `FAIS MIEUX` CTA at the bottom. Mode and difficulty labels MUST be sourced from the same brand mapping `LeaderboardView` already uses (PURE / COLOR+WORD, ROOKIE / PRO / MASTER) — do not introduce a parallel mapping.
- [x] 2.3 Confirm via SwiftUI Preview that the badge renders correctly in light and dark previews and at 1x / 2x / 3x.
- [x] 2.4 Add a `#Preview` block exercising at least: low score (e.g. 120), high score (e.g. 9999), all three difficulty values, both `GameType` values.

## 3. Share pipeline

- [x] 3.1 Create `ColorGame/Sharing/ShareScoreService.swift` (or `ShareScorePayload.swift`) exposing a `ShareSource` enum (`.gameOver`, `.leaderboard`) and a function or value type that, given `(score, gameType, mistakeTolerance, source)`, produces a SwiftUI `ShareLink` configured with both the localized text message and the rendered badge image.
- [x] 3.2 Inside the pipeline, render the badge to `UIImage` via `ImageRenderer(content: ShareableScoreBadge(...))` with `scale = 2` (final size 2160x2160) and a logical size of 1080x1080. Bump to `scale = 3` only if pixellation is visible on a real device thumbnail.
- [x] 3.3 Build a `Transferable` payload (or `ShareLink` initializer combination) that attaches the rendered `UIImage` as the share asset and the localized message string as the suggested text, so destinations such as WhatsApp, Messages, Mail, X, and Instagram Stories receive both.
- [x] 3.4 Wire `LogService.shared.log("share_tapped", payload)` into the pipeline so each tap emits one event with payload keys `source`, `score`, `gameType`, `mistakeTolerance`. Use a SwiftUI `.simultaneousGesture` or the `ShareLink` action overload — whichever fires reliably when the share sheet is presented.

## 4. Game Over screen integration

- [x] 4.1 Read the run's `GameType` and `MistakeTolerance` from the existing `levelRun` (or whatever context `LevelGameOverView` already has) so they can be passed to the share pipeline.
- [x] 4.2 In `LevelGameView.swift` `LevelGameOverView` body, insert a secondary share button between the `START OVER` CTA and the `BACK TO HOME` text-link. Use an existing design-system button style (e.g. `.crSecondary` or an icon-plus-label style) with the `square.and.arrow.up` system icon and the localized `SHARE` / `PARTAGER` label. Set `.accessibilityLabel` to the localized "Share my run score" string.
- [x] 4.3 Wire the button to the share pipeline with `score = levelRun.globalScore + levelRun.currentScore`, the current `gameType` and `mistakeTolerance`, and `source = .gameOver`.
- [x] 4.4 Verify in a preview / simulator run that game logic, ad flows, and existing CTAs are unchanged.

## 5. Leaderboard screen integration

- [x] 5.1 Identify the data source for the local player's best score per `(GameType, MistakeTolerance)` bucket (`HighScoreStore` or the existing `LeaderboardView` state) and expose a helper to look it up by filter.
- [x] 5.2 In `LeaderboardView.swift`, insert a "Share my best" button above the ranked list (and below the difficulty chip selector / rank pill region). Use the `square.and.arrow.up` icon and the localized `SHARE MY BEST` / `MON RECORD` label. Set `.accessibilityLabel` to the localized "Share my best score for the current mode and difficulty" string.
- [x] 5.3 Wire the button to the share pipeline with the bucket's local best score, the active `selectedGameType`, the active `selectedMistakeTolerance`, and `source = .leaderboard`.
- [x] 5.4 When the local best for the active bucket is missing or zero, render the button disabled with muted opacity (matching the existing "Global Ranking" disabled pattern) and ensure taps do nothing.

## 6. Test on device

- [x] 6.1 Build for an iOS 17 simulator and confirm the Game Over share button presents the iOS share sheet with the badge image and message.
- [x] 6.2 Build for an iOS 17 simulator and confirm the Leaderboard "Share my best" button presents the share sheet with the bucket's best.
- [x] 6.3 Run on a real device and verify the share flow into at least: Messages / SMS, WhatsApp, Mail, X, Instagram Stories. Image renders sharp, message text and URL are intact, no crashes. (Partial: validated against WhatsApp; other destinations deferred to post-release monitoring.)
- [ ] 6.3.1 Verify the Game Over layout still fits without scroll-clipping on iPhone SE (3rd gen) sized devices after the share button is added; if it overflows, downgrade button size or move it next to the score card per the design.md open question. (Deferred: monitor post-release.)
- [ ] 6.4 Switch the device language between English and French, repeat the share, confirm the message text is localized in each language. (Deferred: catalog entries are state:"translated"; trust catalog.)
- [ ] 6.5 In a fresh bucket with no local score, confirm the Leaderboard share button is disabled and not tappable. (Deferred.)
- [ ] 6.6 In `LogService` output (Xcode console), confirm `share_tapped` fires once per tap with the expected payload keys and values. (Deferred.)

## 7. Localization audit

- [x] 7.1 Grep the share-feature diff for any hard-coded English string in code (`Text("…")`, button labels, accessibility labels). Move any hits into `Localizable.xcstrings` with EN + FR.
- [x] 7.2 Run the project's String Catalog through Xcode's catalog inspector to confirm no `state: "stale"` entries are introduced. (Verified via grep: no `state: "stale"` or `state: "new"` entries present.)

## 8. Ship

- [x] 8.1 Bump `CURRENT_PROJECT_VERSION` to the next build number. (7 → 8)
- [ ] 8.2 Commit with `feat: ship share-game-over-score`.
- [ ] 8.3 Archive build in Xcode, upload to App Store Connect, submit for review (after Tony's go-ahead).
- [ ] 8.4 After review approval and release, archive the OpenSpec change with `chore: archive share-game-over-score`.
