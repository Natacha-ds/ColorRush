## Context

`LevelGameView` is a 2,598-line file containing the active gameplay UI plus four end-of-state sub-views (level complete, level failed, run complete, game over) and a heavy block of game-state methods (`handleTileTap`, timer ticks, scoring, etc.). Only the **active gameplay** body section is touched by this change — the user is mid-level, tiles visible, timers running. Other states have their own redesign changes (Frames 6, 7, 8) coming later.

The v1 active gameplay state renders:
- Top HUD: Score / Target text top-left, Heart image + lives count top-right, big "Level X" gradient title centered, big "Ns / Time Remaining" timer centered.
- Optional Round-time progress bar above the tile grid (only when `hasTimeLimit && !isNonPunitiveRefresh`).
- 2×2 tile grid using `ColorTile` (Color Only mode) or `ColorAndTextTile` (Color and Text mode).
- Per-level cosmic background `Image("LevelX")` at the very back.
- Overlays: error flash (`Color.red.opacity(0.3)`), streak animation, level-intro modal (already migrated).

Frame 5 redesigns the visual layer; all the underlying game data (`levelRun.currentScore`, `levelRun.getRequiredScore()`, `levelRun.remainingLives`, `levelRun.mistakeTolerance.totalLives`, `levelRun.currentLevel`, `timeRemaining`, etc.) is reused via the same publishers / `@State` variables.

Constraints:
- Pure SwiftUI, no third-party.
- Must consume only design-system primitives in the view layer.
- Must NOT touch game-state methods or the existing `Tile` model.
- iOS 26+, `Canvas` + `TimelineView` available.

## Goals / Non-Goals

**Goals:**
- Migrate the active gameplay layout to Frame 5 1:1.
- Replace the per-level cosmic background image with the tap burst animation Tony asked for.
- Restyle `ColorTile` and `ColorAndTextTile` so they render brand `Theme.Colors.Tile.*` tones for the canonical four colors.
- Wire a back arrow that dismisses the gameplay cover.

**Non-Goals:**
- Modify any game-state method (`handleTileTap`, `startLevel`, `endGameSession`, scoring, lives, timer ticks, level-complete / fail transitions).
- Migrate the post-level states (level complete, level failed, run complete, game over) — those are separate changes.
- Modify the level intro overlay (already shipped).
- Modify the streak animation overlay (separate visual concern, can iterate later).
- Replace the wrong-tap red error flash overlay (kept as-is).

## Decisions

### Decision 1: Tap burst animation via Canvas + TimelineView

The tap animation is driven by a `@State var bursts: [TapBurst] = []` array on the gameplay view. Each `TapBurst` records:

```swift
struct TapBurst: Identifiable {
    let id: UUID
    let origin: CGPoint
    let startTime: Date
    let palette: [Color]
}
```

A `Canvas { context, size in … }` wrapped in `TimelineView(.animation(minimumInterval: 1/60))` reads the elapsed time per burst and draws 8–12 thin line segments at angles spaced evenly around the circle, with length and opacity proportional to a normalized time. Bursts older than ~0.6s are removed from the array via a small cleanup task.

```swift
TimelineView(.animation(minimumInterval: 1/60)) { context in
    Canvas { ctx, size in
        let now = context.date
        for burst in bursts {
            let elapsed = now.timeIntervalSince(burst.startTime)
            guard elapsed < 0.6 else { continue }
            let t = elapsed / 0.6
            // draw beams
        }
    }
}
```

**Why:** Canvas is the lightweight, GPU-friendly path for many short-lived effects; `TimelineView(.animation)` ticks in lockstep with the display refresh; the `@State` array decouples the visual concern from game state.

**Alternative considered:** A bunch of `@State` `Animation` blocks with `withAnimation` per burst. Rejected — harder to manage many concurrent ones, and Canvas is more efficient for line-only drawing.

### Decision 2: Burst origin = tapped tile center

Tile centers are computed deterministically from the grid's frame: 2 columns × 2 rows, with per-tile width / height derived from the grid's available space. The grid container exposes its frame via a `GeometryReader`, which lets us compute `centerOf(tileIndex:)` analytically:

```swift
GeometryReader { geo in
    // tiles render here using the same geo …
    // and so does the Canvas overlay
}
```

The Canvas overlay shares the same geometry, so coordinates match.

**Alternative considered:** Use `SpatialTapGesture` to capture the actual tap point inside each tile. Rejected — adds gesture-conflict risk with the existing Button taps; tile-center bursts look symmetrical and cleaner anyway.

### Decision 3: Brand-color translation for tile rendering

`Tile.backgroundColor` keeps its system `Color` value (`.red`, `.blue`, `.green`, `.yellow`) — game logic in `Tile.isValidHard(announcedColor:)` continues to compare against system colors. At display time only, `ColorTile` and `ColorAndTextTile` translate the system color to its brand counterpart via a small private helper:

```swift
private func brandColor(for systemColor: Color) -> Color {
    switch systemColor {
    case .red: Theme.Colors.Tile.red
    case .blue: Theme.Colors.Tile.blue
    case .green: Theme.Colors.Tile.green
    case .yellow: Theme.Colors.Tile.yellow
    default: systemColor
    }
}
```

**Why:** decouples display from canonical identity, avoids touching `Tile.swift` (which lives close to game logic), keeps the redesign purely additive.

**Alternative considered:** Replace `.red / .blue / .green / .yellow` with brand colors in tile generation, then update `Tile.isValidHard` to compare against brand colors. Rejected — risks subtle bugs in the equality check (tile colors may not be `Equatable`-perfect once they're hex literals), and requires re-validating game logic.

### Decision 4: Back arrow dismisses via `@Environment(\.dismiss)`

The back arrow uses iOS 15+ `@Environment(\.dismiss)` to close the `LevelGameView` `fullScreenCover` and return to the picker (`LevelSystemSelectionView`). The existing chain of fullScreenCovers keeps working; if the user wants to go all the way to Home, they can dismiss the picker too (or use the picker's own back arrow).

**Why:** standard SwiftUI dismissal, no new notification name to introduce. Behavior is "back one screen at a time", which matches the back-arrow semantic.

**Alternative considered:** Post a `DismissToHome` notification that cascades through the cover stack. Rejected — that notification name implies a "go all the way home" action, not "dismiss this cover". Single-step dismissal is more conventional.

### Decision 5: Round-time progress bar — keep as a thin top-of-grid bar

For levels with `hasTimeLimit && !isNonPunitiveRefresh`, we keep the per-tap timeout indicator but render it as a thin horizontal bar (≤4pt) right above the tile grid using `CRProgressBar` semantics or an inline equivalent. Color tone follows the same v1 logic (green when ≥ 30%, red otherwise) but using `Theme.Colors.success` / `Theme.Colors.danger` from the design system.

**Why:** the indicator is a real game mechanic; dropping it would teach by surprise. Restyled minimally so it doesn't visually compete with the score progress bar.

**Alternative considered:** Drop entirely. Rejected — the per-tap pressure is part of higher-level difficulty.

### Decision 6: HUD layout — single VStack, no spacers around the tile grid

The HUD is laid out as:

```
VStack(spacing: …) {
    // Top HUD row: back arrow + SCORE + hearts pill
    // SCORE number (big) + TARGET label + progress bar
    Spacer()
    "LEVEL 01"
    "⏳ 15 SEC LEFT"
    Spacer(minLength: …)
    // Round-time progress bar (conditional)
    // 2x2 tile grid
    Spacer()
}
```

The two `Spacer()`s let the layout adapt to different device heights without manual tuning of magic numbers. The grid stays centered around the screen's vertical middle.

### Decision 7: Score progress capping

`progress = min(1.0, max(0.0, Double(currentScore) / Double(requiredScore)))` with `requiredScore` falling back to `1` if zero (defensive). The progress bar smoothly animates with `.animation(.easeOut, value: levelRun.currentScore)`.

## Risks / Trade-offs

- **[Risk]** Canvas-driven tap animation could affect performance on older simulators or when the level has very fast taps → **Mitigation:** burst array is capped (e.g., max 16 concurrent) and bursts older than 0.6s are pruned each tick; line-only drawing is GPU-cheap.
- **[Risk]** Tile color translation differs from "the v1 colors players are used to" — the brand `Tile.red` (`#E94545`) is slightly less saturated than system `.red` → accepted: visually closer to Frame 5; system colors are too saturated against the dark theme.
- **[Risk]** Back-arrow dismissal during gameplay loses progress without confirmation → accepted for v1 of the redesign; if Tony wants a "Are you sure?" guard, that's a quick follow-up. The user already committed to playing on the picker.
- **[Trade-off]** Round-time progress bar visible only on time-limited levels means users don't see it until level 3+ → matches v1 behavior; not a regression.
- **[Trade-off]** Burst origin at tile center, not tap point, means precision-tappers don't get a "feedback exactly where I tapped" sensation → accepted; symmetrical effect reads cleaner.

## Migration Plan

1. Restyle `ColorTile.swift` to translate system color → brand `Theme.Colors.Tile.*` and use design-system corner radius / shadow.
2. Restyle the inline `ColorAndTextTile` struct in `LevelGameView.swift` (lines ~2517-2548) the same way.
3. Define the inline `TapBurst` struct + `@State var bursts: [TapBurst]` on the gameplay view; add a `Canvas + TimelineView` overlay sized to match the tile grid.
4. Wire `handleTileTap(_:)` to also call `addTapBurst(at:)` with the tile's center coordinate (computed from the grid's `GeometryReader`).
5. Rewrite the active gameplay HUD body (lines ~340-505) with the Frame 5 layout; preserve all data bindings and overlays.
6. Replace the v1 `Image("LevelX")` background with `Theme.Colors.background.ignoresSafeArea()`.
7. Verify in Xcode preview, build, run unit tests, manual sim verification.

Rollback: revert `ColorTile.swift` and the modified portion of `LevelGameView.swift`. Game-state code is untouched.

## Open Questions

- Should the back arrow ask for confirmation before discarding the run? Defer — first iteration: instant dismiss; if Tony notices a misclick risk, add a confirm.
- Should the burst palette be deterministic (same colors per burst) or randomized? Going with rotated palette (each burst takes a slice of the global palette starting at a randomized offset) for visual variety without chaos. Tunable.
