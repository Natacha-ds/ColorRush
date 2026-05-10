## Context

`LevelGameOverView` is invoked from `LevelGameView`'s body when the player has run out of lives (`failedReason == .maxMistakes`). It's a sibling of `LevelFailedView` (already migrated) but shows a different message: the run is over, not just one level.

The view holds an `@StateObject AdsService.shared` and `StoreService.shared` to drive the rewarded-revive button. The closures `onContinueWithExtraLife` and `onBackToHome` are passed in by the parent.

V1 behavior:
- One revive button (+1 Life — Watch Ad) gated by `levelRun.hasUsedRewardedRevive`.
- One "Start a new game" button (calls `onBackToHome`).
- Both visible together until revive is used; once used, only "Start a new game" remains.

Frame 8 introduces:
- A second ad card (+2 LIVES / WATCH 2 ADS) — design intent, but the underlying capability isn't built yet.
- A more dramatic visual layout with the dark red wash and prominent "GAME OVER" headline.

Constraints:
- Pure SwiftUI, no third-party.
- Must consume only design-system primitives in the view layer.
- Must NOT touch game-state methods or the model.
- iOS 26+, can use modern Color / shape APIs.

## Goals / Non-Goals

**Goals:**
- Migrate `LevelGameOverView` to Frame 8 1:1 within the existing struct.
- Preserve every v1 behavior: rewarded revive flow, hasUsedRewardedRevive gating, Remove Ads short-circuit, BACK TO HOME / START OVER exit.
- Render the +2 LIVES card visually but with a clearly disabled state so users see the intent without confusion.

**Non-Goals:**
- Implement the +2 ads chain or +2 lives revive — that's a future game-logic change with its own design considerations (queueing two ads, partial-failure handling, capacity tracking).
- Distinguish START OVER from BACK TO HOME in semantics — both exit to Home in v1; we keep that.
- Re-introduce a "watch an ad to skip ahead" or any other reward mechanic not in v1.
- Migrate `FinalWinView` (the all-10-levels celebration) — out of scope here.

## Decisions

### Decision 1: Layout via inline VStack, not a shared helper

Unlike `LevelCompleteView` and `LevelFailedView` which share `LevelResultBody`, the Game Over screen has a distinct structure (no stat trio, two ad cards, dramatic wash background). A shared helper would force gymnastics; we keep this view's body inline with its own structure.

**Why:** the differences from the result-screens layout are large enough that a generic helper would be more confusing than copy-pasting the structural skeleton. Future divergence stays cheap.

### Decision 2: +2 LIVES card — disabled with "Soon" badge

The card renders visually (so the design is faithful) but its tap area is disabled and a "Soon" label replaces "Watch 2 Ads" inside the secondary button. Opacity is dimmed (≈ 0.55) to communicate disabled state.

**Why:** users see the design intent without hitting a broken button. When the +2 capability ships, we re-enable the card and remove the "Soon" treatment.

**Alternative considered:** hide the card entirely. Rejected — Frame 8 explicitly shows two cards, and rendering one is visually unbalanced.

**Alternative considered:** wire +2 LIVES to repeat the +1 flow twice. Rejected — chaining ads requires game-logic plumbing we don't want to add inside a redesign change.

### Decision 3: `gameOverWash` background

Use `Theme.Gradient.gameOverWash` (the radial dark-red wash already defined in `Theme+Gradient.swift`) as the screen background, layered over `Theme.Colors.background`. Frame 8 shows a subtle dark-red glow centered roughly at the screen center; the wash gradient goes from `Theme.Colors.gameOverWash` (`#3A0A1A`) at the center to `Theme.Colors.background` (`#000000`) at the edges, matching the design.

### Decision 4: "GAME OVER" headline tinted danger

Per Frame 8, the "GAME OVER" text is in `Theme.Colors.danger` (red-pink), `.crDisplay` font, italic, uppercase. Below it, "NO LIVES LEFT" in `.crLabel` with `Theme.Colors.textSecondary`, then a horizontal divider in `Theme.Colors.danger` (matching the headline tint).

### Decision 5: YOUR TOTAL SCORE card — same pattern as result screens

Single `CRCard`-like surface (`Theme.Colors.surface` rounded `Theme.Radius.lg`) containing "YOUR TOTAL SCORE" label + big score number in `.crScoreHero`. The score is `levelRun.globalScore + levelRun.levelPositivePoints` (matching v1's `totalScoreWithCurrentLevel`).

### Decision 6: Ad cards layout

Each ad card is a horizontally laid-out `CRCard`-style container with: a small heart icon on the left tinted `Theme.Colors.accentSecondary` (cyan), a label column with the reward ("+1 LIFE" / "+2 LIVES") in `.crLabel` + a sublabel ("WATCH 1 AD" / "WATCH 2 ADS") in smaller text, a "Watch" button on the right styled as a small primary pill.

The +1 LIFE card preserves the existing v1 wiring (`handleContinueTap` → `markReviveAttempted` + `ads.showRewardedAdIfReady`). Visible only when `!levelRun.hasUsedRewardedRevive`. When the revive is used, the card disappears (just as the v1 button did).

The +2 LIVES card is always visible (until +2 ships), `.disabled(true)`, with a "Soon" treatment on the right button.

### Decision 7: START OVER button — `.crDanger` with refresh icon

Big primary button at the bottom using the existing `.crDanger` button style (red gradient pill from the design system) and the `CRRetry` SVG icon prefix. Calls `onBackToHome` (matches v1's "Start a new game" behavior).

### Decision 8: BACK TO HOME text-link

Below the START OVER button, a small uppercase "BACK TO HOME" text-link styled like the HOME link on result screens (`.crButtonLabel`, uppercase, `Theme.Colors.textSecondary`). Also calls `onBackToHome` — same destination as START OVER, but lower visual weight so the user understands it's a quieter exit.

If Tony later wants distinct behaviors, we'd add an `onResetRun` closure parameter. For now, both go to Home.

## Risks / Trade-offs

- **[Risk]** Both START OVER and BACK TO HOME do the same thing (exit to Home) → could feel redundant. Accepted: the visual hierarchy (big primary CTA vs. small text link) communicates the same hierarchy as the result screens (NEXT LEVEL vs HOME), so the user understands. If Tony wants real semantic difference (e.g., START OVER actually starts a new run automatically), we add it later.
- **[Risk]** "+2 LIVES" rendered but disabled may confuse users who see the affordance and try to tap → **Mitigation:** the "Soon" badge plus dimmed opacity should communicate clearly. We keep it visible because Frame 8 shows two cards; hiding one feels wrong visually.
- **[Trade-off]** Inline body without a shared helper means future changes to the result-screens family (Complete / Failed / GameOver) require touching three places → accepted: the structural differences are large enough that DRY would force unnatural shapes.

## Migration Plan

1. Rewrite `LevelGameOverView.body` (line ~2252 onward) with the new dark layout.
2. Drop unused private helpers (e.g., `lossReason` if no longer referenced).
3. Verify in Xcode preview against `screens/Frame 8.png`.
4. Build, unit tests, manual sim verification (force a run-end via the dev Skip button or by losing all lives in INSANE mode).

Rollback: revert the single struct's body. Game state and adjacent views are untouched.

## Open Questions

- Should the +2 LIVES card use a different icon (e.g., two hearts overlapped) or the same single-heart icon as +1 LIFE? Going with single heart + bigger reward label for now — easy to swap if Tony has a preference.
- Should "Start Over" trigger a fresh run automatically (return to Home + auto-tap PLAY), or just dismiss to Home (current v1 behavior)? Going with v1 behavior — Tony can call out a different intent.
