## Context

`LevelCompleteView` and `LevelFailedView` are two SwiftUI structs declared inline at the bottom of `LevelGameView.swift`. Each takes a `LevelRun`, an action closure (next level / retry), a back-to-home closure, and renders a v1 light-themed result screen with a verbose score breakdown card, animated medals, and emoji icons.

Frame 6 and Frame 7 redesign these as visual siblings — identical layout with inverted tone (orange/skull for failed, green/lightning for success). The core data displayed is the same: total score, hearts remaining, level result (success/fail), level score vs target, stat breakdown (hits / misses / streak), and a CTA + home link.

Constraints:
- Pure SwiftUI, no third-party.
- Must consume only design-system primitives — leverage the existing `CRHeartsPill`, `CRStatBadge`, `CRCard`.
- Must NOT touch game-state methods or the `LevelRun` model.
- iOS 26+, can use `.symbolRenderingMode(.palette)` and similar modern Image APIs if useful.

## Goals / Non-Goals

**Goals:**
- Rewrite both views in place using design-system primitives.
- Factor a small shared layout helper (`LevelResultLayout` or similar) so the two views don't duplicate the structural skeleton — the differences are tone, icon, headline, button label.
- Map all displayed values to the existing `LevelRun` properties used in v1 to preserve numerical correctness.

**Non-Goals:**
- Modify any game-state method or `LevelRun` model.
- Migrate `FinalWinView` (the special all-10-levels celebration — different design, separate concern).
- Migrate the run-ending game-over view (Frame 8 — bundled with the rewarded-ad flow, separate change).
- Add new behaviours (e.g., share button, replay button, video reward) — strict visual parity with v1 behaviour.

## Decisions

### Decision 1: Shared layout via a private helper view

A private `LevelResultLayout<TopContent, IconContent, ActionContent>` view (or a parameterized wrapper `LevelResultBody`) is declared at module scope to render the common structure. Each per-screen struct (`LevelCompleteView`, `LevelFailedView`) populates the slots with its tone-specific content.

```swift
private struct LevelResultBody: View {
    let totalScore: Int
    let remainingLives: Int
    let totalLives: Int
    let icon: Image
    let iconTint: Color
    let headline: String
    let subtitle: String
    let dividerColor: Color
    let levelScore: Int
    let requiredScore: Int
    let hitsValue: Int
    let missesValue: Int
    let streakValue: Int
    let primaryButton: AnyView
    let onBackToHome: () -> Void
}
```

**Why:** the two views differ in 4 places (icon, headline, subtitle suffix, button) and a tone color. Everything else is identical. A shared body layout keeps the diff manageable, ensures pixel-level parity between the two screens, and centralises future changes (one edit affects both).

**Alternative considered:** keep the two structs fully independent, copy the layout. Rejected — leads to drift over time; one of the screens will get an update the other doesn't.

### Decision 2: Icons via SF Symbols, not asset import

Skull (failed) → `Image(systemName: "skull")` tinted `Theme.Colors.warning`. Lightning bolt (success) → `Image(systemName: "bolt.fill")` tinted `Theme.Colors.success`. Sparkles surrounding the bolt → omitted in v1 of the redesign (start simple); add later via additional `Image(systemName: "sparkle")` overlays at random positions if Tony wants more flair.

**Why:** SF Symbols give us free dynamic type, simple tinting, and no asset bundle weight. The legacy `Game-Over.imageset` and `Bomb.imageset` in the asset catalog are v1 emoji rasterizations; we leave them in place for now.

### Decision 3: Stats trio always shown (drop conditional flags)

V1 hides MISSES on levels 1-2 and 9-10 via `shouldShowMissed`, and conditionally hides BONUS via `shouldShowBonus`. The new design always shows all three stat badges. If the user has 0 misses or 0 streak bonus, the badge simply shows `0` — visual consistency across all levels.

**Why:** Frame 6 and Frame 7 both clearly show all three slots. Hiding stats is more confusing than showing zeros.

### Decision 4: Stat values formatted with explicit sign

- HITS: `+\(levelBasePoints)` (always positive, `+` prefix), green tone (`success`)
- MISSES: a negative number when there are penalties, otherwise `0`. We compute as `-(levelWrongTaps * 10)` and display as `\(value)` (the minus sign is part of the number). Orange tone (`warning`).
- STREAK: `+\(levelStreakBonuses)` (always positive, `+` prefix), cyan tone (`info`).

`CRStatBadge` already accepts a `value: String` and a `tone: Tone`. We pass formatted strings.

**Why:** matches Frame 6 / Frame 7 exactly: "+110 / -15 / 0" / "+240 / 0 / +20".

### Decision 5: TOTAL SCORE row layout

Top of the screen: a left-aligned `VStack` with "TOTAL SCORE" label (`.crLabel`, `Theme.Colors.textSecondary`, uppercase) over the cumulative score number (`.crTitle`, `Theme.Colors.textPrimary`); a `Spacer()`; a right-aligned `CRHeartsPill(remaining: …, total: …)`.

The cumulative score is `levelRun.globalScore + levelRun.levelPositivePoints` (matches v1 `totalScoreWithCurrentLevel`). On the failed screen the value is the same — the level's positive points are still earned even on failure (they were just not enough or the lives ran out).

### Decision 6: YOUR SCORE card

A `CRCard`-styled container (or an inline equivalent) showing:
- "YOUR SCORE" label (`.crLabel`, uppercase, `Theme.Colors.textSecondary`)
- The level score in a very large `.crScoreHero` (56pt black italic) `Theme.Colors.textPrimary`
- "OF NNN" subtitle (`.crBody`, `Theme.Colors.textSecondary`) showing the level's required score

The level score is `levelRun.getCurrentLevelScore()` — already used by v1.

### Decision 7: HOME link styling

Below the primary CTA, a small uppercase "HOME" text styled as `.crButtonLabel` (Bold non-italic 16pt) `Theme.Colors.textPrimary`. Tappable via a transparent `Button` with `.crIcon`-equivalent treatment, calls `onBackToHome`.

**Why:** Frame 6 and Frame 7 both show a small text link, not a full button. Centred under the primary CTA.

### Decision 8: Failed-screen retry icon inside the button

Frame 6 shows a small refresh-arrow icon left of "TRY AGAIN". Use SF Symbol `arrow.clockwise` (or `arrow.counterclockwise`) sized 18pt bold, prefixed inside the primary button label.

## Risks / Trade-offs

- **[Risk]** The shared `LevelResultBody` wrapper makes the two views identical structurally, which is a desired property — but it also means a future divergence (e.g., adding a "share" button on success only) requires re-introducing per-view branching → accepted: cheap to refactor when needed.
- **[Risk]** Dropping conditional `shouldShowMissed` / `shouldShowBonus` means levels 1-2 now show "MISSES: 0" instead of hiding the slot → accepted: visually more consistent; users learn the badge layout faster.
- **[Risk]** SF Symbol skull may render slightly differently from the orange skull in Frame 6 (the design's skull has a distinctive "brain crown" treatment) → **Mitigation:** the SVG `screens/assets/Frame-3.svg` (Frame 6's skull asset) is available; if the SF Symbol render is too plain, import as an asset in a follow-up tweak.
- **[Trade-off]** No sparkles around the lightning bolt in v1 of the redesign → simpler, ships faster; can add later with `Image(systemName: "sparkle")` overlays.

## Migration Plan

1. Declare a private `LevelResultBody` view in `LevelGameView.swift` near the bottom (before the existing `LevelCompleteView` struct), parameterised by the per-screen content.
2. Rewrite `LevelCompleteView.body` to call `LevelResultBody` with success-tone content (green tint, lightning bolt, "AMAZING", "Next Level" CTA, etc.).
3. Rewrite `LevelFailedView.body` similarly with failed-tone content.
4. Drop v1 helpers (`correctAnswersDisplayValue`, `mistakesPenalty`, `timeoutsPenalty`, `shouldShowBonus`, `shouldShowMissed`, etc.) that are no longer referenced after the rewrite.
5. Verify in Xcode preview against `screens/Frame 6.png` and `screens/Frame 7.png`.
6. Build, unit tests, manual sim verification.

Rollback: revert the two struct bodies. Game state is untouched.

## Open Questions

- Should the success screen include a celebratory burst (the same CAEmitterLayer spark from gameplay, fired once on appear)? Skipping for V1 of this change — keep it simple. Easy follow-up if Tony wants more pop.
- The "OF NNN" target on the failed screen is the level's required score (the player didn't reach it). The exact phrasing in the design is "OF 250" — we use the same in both screens for parity.
