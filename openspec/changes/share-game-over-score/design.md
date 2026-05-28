## Context

ColorRush v1.0.1 ships with no built-in sharing. The deployment target was just lowered to iOS 17.0, which unlocks both `ShareLink` (iOS 16+) and `ImageRenderer` (iOS 16+) as first-class SwiftUI primitives, so no UIKit bridge is needed. The app already uses `LogService.shared.log(event, payload)` for analytics with kebab-style event names, so the share pipeline plugs in without new infrastructure. The Game Over screen (`LevelGameOverView` in `LevelGameView.swift:2317`) and the Leaderboard screen (`LeaderboardView.swift`) are the two end-of-something moments where players are most likely to want to share.

## Goals / Non-Goals

**Goals:**
- One reusable share entry point that can be invoked from any screen with a score and a context.
- Image badge that renders the score, the mode, and the difficulty in a brand-consistent visual, packaged as a square `UIImage` ready for the iOS share sheet.
- Localized share text (EN + FR) that includes the score and the App Store URL `https://apps.apple.com/app/id6766084527`.
- One `share_tapped` analytics event per tap, with enough payload to slice by source screen, mode, and difficulty.
- Implementation under iOS 17 deployment target, no third-party SDK.

**Non-Goals:**
- Sharing other players' scores from the leaderboard list (only the local player's best).
- Sharing from `LevelCompleteView` (per-level success) or `LevelFailedView` (per-level fail). Run Completed and per-level results are out of scope for v1 of share.
- Capturing share completion (the iOS share sheet does not expose a reliable per-destination completion callback, and `ShareLink` does not provide a generic completion handler). Only the tap is tracked.
- Pre-share confirmation dialog. Tapping the button presents the share sheet directly.
- Deep links into the app. The shared URL points to the App Store listing only.

## Decisions

### Decision 1: Use `ShareLink` with a custom `Transferable` payload

`ShareLink` is the SwiftUI-native API for iOS 16+ and matches the iOS 17 deployment target. To attach both an image and a text message we expose a `Transferable` payload that supplies the image as the primary representation and the message as a suggested text. `ShareLink` then renders a system share sheet that auto-populates SMS, WhatsApp, Messages, Mail, X, Instagram Stories, etc., based on what is installed.

**Alternatives considered:**
- `UIActivityViewController` wrapped in `UIViewControllerRepresentable`: works but adds UIKit glue and a custom view controller lifecycle. `ShareLink` is the modern default and uses fewer lines.
- Multiple `ShareLink`s per destination (one for SMS, one for WhatsApp via deep link, etc.): brittle, requires URL scheme handling, and bypasses the system share sheet that users already understand.

### Decision 2: Render the badge with `ImageRenderer`, scale 2, at view-build time

The share badge is a SwiftUI view (`ShareableScoreBadge`) configured with score, mode, and difficulty. Just before presenting the share sheet, the view is rendered to `UIImage` via `ImageRenderer(content:)` with a fixed `scale = 2.0` (final raster size 2160x2160 from a logical 1080x1080). 2x is sharp enough for every chat thumbnail destination tested and keeps the image around 1-2 MB instead of the 4-5 MB a 3x render would produce. The image is not persisted to disk — it lives only as long as the share sheet is on screen. Bump to `scale = 3` only if pixellation is visible on a real device.

**Alternatives considered:**
- Pre-rendering a static template and overlaying text via Core Graphics: harder to maintain, doesn't reuse the design system tokens.
- Rendering at the platform's native scale dynamically per device: marginal gains, more variance across devices. Fixed 3x is a clean default.

### Decision 3: Single SwiftUI helper view, two callers

A SwiftUI helper view `ScoreShareLink` wraps `ShareLink`, takes `(score: Int, gameType: GameType, mistakeTolerance: MistakeTolerance, source: ShareSource)`, and exposes the full label + accessibility configuration to its caller via a `@ViewBuilder` label closure. Both `LevelGameOverView` and `LeaderboardView` instantiate this view so the message, image, and analytics stay consistent across screens. `ShareSource` is an internal enum (`.gameOver`, `.leaderboard`) used only for analytics.

Chosen over a plain `ShareScoreService` struct because SwiftUI is the rest of the app's idiom and `ShareLink` only lives inside a view hierarchy — the wrapper composes naturally and avoids manual `UIActivityViewController` plumbing.

**Alternatives considered:**
- Duplicate the `ShareLink` configuration in each call site: drifts over time, harder to keep the message templating in sync.

### Decision 4: Leaderboard share targets the local player's best for the current filter

The Leaderboard view already drives a `(GameType, MistakeTolerance)` filter selector. The "Share my best" button reads the local player's best score from `HighScoreStore` (or the existing data source used by `ScoreRowView`) for that exact bucket and shares it. If no local score exists for the bucket, the button is disabled with a muted style so the user understands they need to play that mode first.

**Alternatives considered:**
- Share the user's globally best score regardless of filter: confusing relative to what the user is looking at.
- Share whatever is currently highlighted in the list: only works if `isLocalPlayer == true` somewhere in the visible rows.

### Decision 5: Localized message template via `Localizable.xcstrings`, score via `Int.formatted()`

The share message uses a single localized template with two replacement tokens (`%@` for the formatted score, `%@` for the App Store URL). The English and French strings live in `Localizable.xcstrings` alongside every other user-facing string. No hard-coded English in code.

The score is converted to a locale-aware string via `score.formatted()` before substitution (e.g. `1,420` in English, `1 420` in French), matching the formatting the leaderboard already uses for its score column.

Draft EN: `I scored %@ points on ColorRush. Can you beat me? %@`
Draft FR: `J'ai marqué %@ points sur ColorRush. Tu peux faire mieux ? %@`

(Final wording locked during implementation. The catalog tests will refuse any hard-coded English.)

### Decision 6: Reuse the leaderboard brand label mapping for mode and difficulty

`LeaderboardView` already owns the brand label mapping (`PURE` / `COLOR+WORD` for `GameType`, `ROOKIE` / `PRO` / `MASTER` for `MistakeTolerance`). The share badge MUST source its mode and difficulty labels from that same mapping so the share output stays consistent with what the player sees on the Leaderboard. The implementation lifts the mapping out of `LeaderboardView` into a small helper if needed (e.g. `extension GameType { var brandLabel: LocalizedStringKey }`) and reuses it in both places, rather than defining a parallel set of strings inside `ShareableScoreBadge`.

### Decision 7: Analytics event `share_tapped` with stable payload schema

One event name across both call sites. Payload keys:
- `source`: `"game_over"` or `"leaderboard"`.
- `score`: `Int`.
- `gameType`: `GameType.rawValue`.
- `mistakeTolerance`: `MistakeTolerance.rawValue`.

This matches the existing `LogService` conventions (kebab-style event names, snake_case-ish payload keys) used in `LeaderboardView.swift:297` and elsewhere.

## Risks / Trade-offs

- [iOS share sheet completion is opaque] → We only log `share_tapped`. If we ever need conversion data, we will rely on App Store referral attribution rather than in-app callbacks.
- [Badge image not rendering correctly on every destination] → Mitigated by testing on real device against WhatsApp / Messages / Mail / X / IG Stories before shipping. Square 1080 is the common-denominator format that all of these accept gracefully.
- [Localized template tokens out of order] → `Localizable.xcstrings` supports positional arguments (`%1$lld`, `%2$@`). If the French template needs different ordering than English, switch to positional tokens during implementation.
- [Leaderboard local best may be empty for a fresh bucket] → Button disabled with an unobtrusive disabled style and (optionally) a one-line hint, mirroring the existing "Sign in to Game Center to see the global ranking" pattern at `LeaderboardView.swift:326`.
- [Share button on Game Over crowds an already-dense layout] → The button is added as a small secondary action (label `SHARE` / `PARTAGER` with `square.and.arrow.up` icon) positioned between the `START OVER` primary CTA and the `BACK TO HOME` text-link, so the visual hierarchy stays primary CTA > secondary share > tertiary back-to-home.
- [Layout overflow on iPhone SE class devices] → Game Over already stacks hearts pill, headline, subtitle, divider, score card, prompt, subtitle, ad card, primary CTA, and back-to-home link. Adding a share button may force scroll clipping on smaller screens. Mitigation: test on iPhone SE (3rd gen) in task 6.3.1; if it overflows, downgrade the share affordance to an icon attached to the YOUR TOTAL SCORE card instead of a full button row.
- [X / Twitter strips attached images on some link-share flows] → Out of scope to fully solve. The text + URL always lands cleanly; the image is best-effort. WhatsApp, Messages, Mail, IG Stories, and Mail handle the `Transferable` image reliably and cover the most-shared destinations.

## Migration Plan

No data migration. The feature is additive UI. No changes to leaderboard storage, Game Center scoring, ads, or IAP. Ship as build 8 (or later) of v1.0.x, no impact on existing players.

## Open Questions

- Exact placement on the Game Over screen: between `START OVER` and `BACK TO HOME` is the current proposal, but the implementation may move it to a small icon attached to the YOUR TOTAL SCORE card if the secondary button feels heavy in practice.
- Whether the badge background should use `Theme.Gradient.gameOverWash` on the Game Over share and a different gradient on the Leaderboard share, or a single neutral brand gradient regardless of source. Default: single neutral brand gradient so the badge looks the same in every share thread.
