## Why

Once the user taps PLAY on the level intro modal, they land in `LevelGameView`'s active gameplay state — the only screen left running on its v1 light-themed visuals (gradient titles, system fonts, white shadows, per-level cosmic Image backgrounds). Migrating it completes the dark-themed redesign for the in-run path and validates the design system on the densest screen of the app (HUD + filters + tiles + animations). It also lets us replace the v1 static `Image("LevelX")` cosmic backgrounds with a code-driven tap animation Tony has been asking for since the design-system foundation shipped.

## What Changes

- Rebuild the active gameplay layout inside `LevelGameView` to match Frame 5: pure-black background; top HUD with a back arrow + SCORE label and number on the left and a `CRHeartsPill` on the right; below the score, a "TARGET: N" cyan label and a `CRProgressBar` showing `currentScore / requiredScore`; mid-section with a centered "LEVEL XX" big italic title and a small hourglass icon + "N SEC LEFT" countdown; the existing 2×2 tile grid centered below.
- Replace the v1 per-level `Image("Level\(currentLevel)")` cosmic backgrounds with a code-driven **tap burst animation**: each tile tap emits 8-12 thin "light beam" line segments emanating from the tapped tile's center, each tinted with a brand color (rotating across `Theme.Colors.accent` / `accentSecondary` / `pro` / `danger` / `logoOrange` / `logoMagenta`), expanding outward over ~0.5s with linear motion and a soft fade-out at the end. Multiple concurrent taps each get their own independent burst.
- Update `ColorTile` and `ColorAndTextTile` rendering to translate the canonical system colors (`.red`, `.blue`, `.green`, `.yellow`) to the brand `Theme.Colors.Tile.*` palette at display time. The tiles' `Color`-typed API stays unchanged — game logic in `Tile.isValidHard(...)` continues to compare system colors as before.
- Drop the v1 visual elements that don't appear on Frame 5: the "Time Remaining" subtitle below the timer, the gradient text on the level title, the legacy `Heart.imageset` + lives count text (replaced by `CRHeartsPill`), the per-level cosmic background image. Round-time progress (the per-tap timeout indicator for levels with `hasTimeLimit && !isNonPunitiveRefresh`) is preserved but restyled as a thin bar above the tile grid using design-system tokens.
- Wire the back arrow at the top-left to `@Environment(\.dismiss)`, dismissing the `LevelGameView` full-screen cover and returning to the picker (existing fullScreenCover stack handles further dismissal to Home).
- **No game logic changes**. `handleTileTap`, scoring, lives, level timers, `pendingIntroDismiss`, level-complete / fail transitions, streak animation, error flash, and the level-intro overlay (already migrated) all stay as-is.

## Capabilities

### New Capabilities
- `gameplay-screen`: View-layer contract for the redesigned active gameplay surface — what the HUD shows, how the tap burst animation behaves, how the back arrow dismisses, and how the screen composes with the unchanged game-logic capabilities.

### Modified Capabilities
<!-- None. The existing `level-gameplay` capability defines run / level lifecycle and scoring; that's untouched. -->

## Impact

- **Modified**: `ColorGame/LevelGameView.swift` — rewrites only the active gameplay portion of the body (≈250 lines starting around line 340 and ending before the post-level / game-over states), plus the `LevelIntroView` already shipped. The 1,500+ lines of game-logic methods (`handleTileTap`, `startLevel`, scoring, etc.) are untouched. `ColorGame/ColorTile.swift` — restyle the rendered tile to use design-system tokens. `ColorGame/LevelGameView.swift::ColorAndTextTile` (inline at the bottom) — same restyle.
- **Unchanged**: `LevelSystemModels.swift`, `Tile.swift` (game logic intact), `RulesView.swift`, every other screen.
- **No new dependencies**: pure SwiftUI, uses iOS 26-available `Canvas` + `TimelineView` for the tap animation.
