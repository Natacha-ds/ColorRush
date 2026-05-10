## Why

After completing or failing a level, the player lands on either `LevelCompleteView` or `LevelFailedView` — two screens still on v1 light styling (gradient backgrounds, white cards, system fonts, emoji medals) embedded inline in `LevelGameView.swift`. Frames 6 and 7 redesign these as visual siblings: same dark structure with content inverted (skull / orange for failed, lightning bolt / green for success). Migrating both in a single change yields one coherent visual language for level outcomes and lets us factor shared building blocks (top score row, stats trio, divider, action area) without duplicating work between two changes.

## What Changes

- Rebuild `LevelCompleteView` (Frame 7) and `LevelFailedView` (Frame 6) using only design-system primitives. Both views are inline structs in `LevelGameView.swift` (lines ~1867 for Complete, ~2162 for Failed) — rewritten in place.
- **Shared structure** (both views): TOTAL SCORE label + cumulative score on the top-left + dimmed `CRHeartsPill` on the top-right; a centered tone-coloured icon (lightning bolt for success, skull for failed); a `.crDisplay` headline ("AMAZING" / "TOO SLOW"); a small "LEVEL XX - SUCCEED" / "LEVEL XX - FAILED" subtitle; a horizontal tone-coloured divider line; a centered YOUR SCORE card showing the achieved level score and "OF NNN" target; a row of three `CRStatBadge`s — HITS (positive points, success tone), MISSES (penalty points, warning tone), STREAK (bonus points, info/cyan tone); a primary CTA at the bottom; a small "HOME" text-link below.
- **Per-screen content**:
  - **Success**: green tone (`Theme.Colors.success`), lightning-bolt SF Symbol with sparkles surrounding, "AMAZING" headline, "NEXT LEVEL" `.crPrimary` CTA wired to the existing `onNextLevel` closure.
  - **Failed**: orange tone (`Theme.Colors.warning`), skull SF Symbol, "TOO SLOW" headline, "TRY AGAIN" `.crPrimary` CTA with refresh icon wired to the existing `onRetry` closure.
- The dim/full state of the hearts pill on each screen reflects `levelRun.remainingLives` exactly as v1 does — failed is shown when a life was lost (so usually fewer hearts), succeeded is shown with whatever lives remain.
- Wire SCORE / TARGET / HEARTS / HITS / MISSES / STREAK from the existing `LevelRun` properties exactly as v1 (`globalScore + levelPositivePoints` for the top total, `getCurrentLevelScore()` for the level score, `levelBasePoints` for HITS, `levelWrongTaps * -10` for MISSES, `levelStreakBonuses` for STREAK). The HOME text-link calls `onBackToHome` (existing behavior).
- Drop v1 visual elements that don't appear on the new design: the gradient background, the inline animations / score breakdown explanations, the medal emoji icons, the scroll-style score breakdown card, and `Image("Heart")` (replaced by `CRHeartsPill`). Conditional show flags `shouldShowBonus` / `shouldShowMissed` are dropped — the new design always shows all three stat badges.
- **No game logic changes**. `isLevelComplete` / `isLevelFailed` transitions, `levelComplete()` / `failedReason` / `startNewLevel` mechanics, score and stat computation, ad presentation, leaderboard submission all stay as-is.

## Capabilities

### New Capabilities
- `level-result-screens`: View-layer contract for the redesigned post-level outcome screens — what each view displays, how the two screens share structure, and how they compose with the unchanged level-gameplay capability.

### Modified Capabilities
<!-- None. The existing `level-gameplay` capability defines run / level lifecycle and scoring; that's untouched. -->

## Impact

- **Modified**: `ColorGame/LevelGameView.swift` — only the inline `LevelCompleteView` (≈295 lines, lines ~1867-2161) and `LevelFailedView` (≈254 lines, lines ~2162-2415) struct bodies are rewritten. The 1500+ lines of game-logic methods + the active gameplay layout (already migrated) stay untouched.
- **Unchanged**: `LevelSystemModels.swift`, `Tile.swift`, `RulesView.swift`, `FinalWinView` (the all-10-levels celebration is a separate screen, not in our 9 inventoried frames), the run-ending game-over view (Frame 8 — separate change).
- **No new dependencies**: pure SwiftUI, consumes only existing design-system primitives + the `CRHeartsPill` / `CRStatBadge` / `CRCard` shared components.
