## Why

After tapping PLAY on the redesigned Home, the user lands on the v1 `LevelSystemSelectionView` — light theme, white cards with chevrons, system fonts, emoji icons. It's the most visible mismatch in the user journey because it sits between the new Home and the (still v1) gameplay. This change migrates the picker to Frames 2 and 3, completes the entry-flow visual coherence (Home → Mode → Difficulty), and validates the design system against a multi-step navigated screen. Game state machinery (`LevelRun`, enum cases) is already in good shape and stays unchanged; only the view layer is touched.

## What Changes

- Rebuild `LevelSystemSelectionView` to match Frames 2 and 3:
  - **Step 1 (Frame 2 — "PICK A MODE")**: "STEP 1/2" small label + back-arrow + "PICK A MODE" headline; two cards stacked vertically — "Color ONLY" and "Color and Text" — each showing a mini 2×2 swatch grid (Color ONLY uses bare color tiles; Color and Text uses tiles with the word labels) and a short description; an explicit "CONTINUE" CTA at the bottom (replacing v1's auto-advance on selection).
  - **Step 2 (Frame 3 — "HOW HARD?")**: "STEP 2/2" + back-arrow + "HOW HARD?" headline; three cards — "ROOKIE", "PRO", "INSANE" — each showing the brand label, a description ("5 lives — good to start" etc.), and a row of hearts (5 / 3 / 1); active card uses a difficulty-coloured accent border (green Rookie, gold Pro, red Insane); a "LET'S GO" CTA at the bottom.
- Add a "**Recommended to start**" chip on the Color ONLY card, **conditional**: shown only when the user has no completed runs in any `(colorAndText, *)` bucket (read directly from `LeaderboardStore.shared.scoresByKey`). The chip disappears as soon as the user finishes one Color + Text level.
- Map enum cases to brand labels via private extensions inside `LevelSystemSelectionView.swift`:
  - `colorOnly` → "PURE", `colorAndText` → "COLOR+WORD" (used as small headers / footer cues if needed)
  - `easy` → "ROOKIE", `normal` → "PRO", `hard` → "INSANE"
  - The mode card primary headlines stay friendly ("Color ONLY", "Color and Text") matching Frame 2 wording — these are display strings, not enum-driven, defined inline in the view.
- **Drop the v1 "How to play?" link**. `RulesView` and its trigger code stay in `LevelSystemSelectionView` only as commented-out / removed reference; the `RulesView.swift` file itself is **not** deleted because we'll surface it elsewhere in a later change (a Settings entry, long-press on PLAY, etc., to be designed).
- Replace v1 visual elements (white cards, chevrons, emoji rocket button, light gradient bg, progress dots) with design-system primitives: `CRCard`, `CRChip`, `CRSectionHeader`, `.crPrimary` button style.
- **No changes** to `LevelRun`, `LevelSystemModels.swift`, `LevelGameView`, or any service. `RulesView.swift` is left intact.

## Capabilities

### New Capabilities
- `level-system-selection`: View-layer contract for the redesigned mode-and-difficulty picker — the two-step flow, the "Recommended to start" recommendation rule, the back-navigation behavior, and how it composes with the existing `LevelRun` state object on game start.

### Modified Capabilities
<!-- None. The existing game-logic capabilities (level-gameplay) define run lifecycle and difficulty semantics; those are unchanged. -->

## Impact

- **Modified**: `ColorGame/LevelSystemSelectionView.swift` (full rewrite of the body and inline subviews).
- **Unchanged**: `ColorGame/LevelSystemModels.swift`, `ColorGame/LevelRun*` (the `LevelRun` ObservableObject lives in `LevelSystemModels.swift`), `ColorGame/LevelGameView.swift`, `ColorGame/RulesView.swift`, `ColorGame/HomeView.swift`, `ColorGame/MainTabView.swift`.
- **No new dependencies**: pure SwiftUI, consumes the existing design-system primitives + `LeaderboardStore` for the recommendation check.
