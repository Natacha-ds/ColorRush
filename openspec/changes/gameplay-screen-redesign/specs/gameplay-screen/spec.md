## ADDED Requirements

### Requirement: Active gameplay layout

While the user is playing a level (not in the level-intro overlay, not in a post-level state), `LevelGameView` SHALL render the screen on a black background with the following structure, matching Frame 5: a top HUD row containing a left-aligned back arrow + SCORE label + score number, and a right-aligned `CRHeartsPill`; below the score, a "TARGET: N" cyan label paired with a `CRProgressBar` showing `currentScore / requiredScore`; in the mid-section, a centered "LEVEL XX" display title (zero-padded) and below it an SF Symbol hourglass + "N SEC LEFT" countdown; an optional thin round-time progress bar above the tile grid for time-limited levels; and a 2×2 tile grid centered below.

#### Scenario: Initial render
- **WHEN** the level intro overlay dismisses and gameplay begins
- **THEN** the screen renders on `Theme.Colors.background` with the back arrow, SCORE label and number (initially 0), TARGET label and progress bar, current LEVEL display, current timer, and the 2×2 tile grid all visible

#### Scenario: HUD reflects state changes
- **WHEN** `levelRun.currentScore` or `levelRun.remainingLives` changes during play
- **THEN** the SCORE number, the TARGET progress bar fill, and the hearts pill update reactively without re-mounting the screen

### Requirement: Tile rendering uses brand tile colors

`ColorTile` and `ColorAndTextTile` SHALL translate the canonical system `Color` they receive (`.red`, `.blue`, `.green`, `.yellow`) to the brand `Theme.Colors.Tile.*` palette at render time. The `Tile.backgroundColor` value (used by `Tile.isValidHard(...)` for game-logic equality) SHALL remain a system `Color` and SHALL NOT be modified.

#### Scenario: Color Only red tile
- **WHEN** the tile generator produces a `ColorTile(color: .red, ...)`
- **THEN** the rendered tile fill is `Theme.Colors.Tile.red`, not the system `.red`

#### Scenario: Color and Text yellow tile
- **WHEN** the tile generator produces a `ColorAndTextTile(tile: Tile(backgroundColor: .yellow, ...))`
- **THEN** the rendered tile fill is `Theme.Colors.Tile.yellow`, the inner label color contrast logic is preserved (yellow → black text)

#### Scenario: Game logic untouched
- **WHEN** `Tile.isValidHard(announcedColor:)` is invoked
- **THEN** the comparison is done against system `Color` values exactly as before; no brand-color comparison appears in the model

### Requirement: Tap burst animation

When the user taps a tile (correct or wrong), the gameplay screen SHALL emit a visual "burst" animation: 8 to 12 thin line segments emanating from the tapped tile's center, each tinted with a brand color drawn from the palette `[Theme.Colors.accent, Theme.Colors.accentSecondary, Theme.Colors.pro, Theme.Colors.danger, Theme.Colors.logoOrange, Theme.Colors.logoMagenta]`. Each segment SHALL extend outward from the origin over approximately 0.5–0.6 seconds with a fade-out at the end. Multiple concurrent taps SHALL each get their own burst rendered independently.

#### Scenario: Tap emits burst
- **WHEN** the user taps any tile during active gameplay
- **THEN** a burst of 8–12 thin colored line segments appears emanating from that tile's center and animates outward, fading out by ~0.6 seconds

#### Scenario: Concurrent bursts are independent
- **WHEN** the user taps two different tiles in quick succession
- **THEN** both bursts render simultaneously, each on its own timeline; neither cancels the other

#### Scenario: Bursts do not affect game state
- **WHEN** comparing the visual burst code path with the game-state code path
- **THEN** the burst animation reads only from a local `@State var bursts: [TapBurst]` array; it does not read from or write to `LevelRun`, `currentScore`, `remainingLives`, or any other game-state value

#### Scenario: Burst on wrong tap coexists with the error flash
- **WHEN** the user taps a wrong tile
- **THEN** both the tap burst animation AND the existing v1 wrong-tap red error flash overlay render; neither is suppressed by the other

### Requirement: Back arrow dismisses

The top-left back arrow on the active gameplay screen SHALL invoke `@Environment(\.dismiss)`, dismissing the `LevelGameView` full-screen cover and returning the user to the previous screen in the navigation stack.

#### Scenario: Back arrow tap
- **WHEN** the user taps the back arrow during active gameplay
- **THEN** `dismiss()` is called and `LevelGameView` is removed from the view hierarchy; no confirmation dialog is shown in this version

### Requirement: Round-time progress bar restyled

For levels where `levelConfig.hasTimeLimit && !levelConfig.isNonPunitiveRefresh`, the per-tap round-time indicator SHALL be rendered as a thin (≤ 4pt) horizontal bar above the tile grid, coloured `Theme.Colors.success` when `roundTimeRemaining > 30%` of the round limit and `Theme.Colors.danger` otherwise.

#### Scenario: Round-time bar visible on time-limited levels
- **WHEN** rendering a level with `hasTimeLimit == true` and `isNonPunitiveRefresh == false`
- **THEN** a thin progress bar appears above the tile grid showing the remaining round time; the bar's fill width tracks `roundTimeRemaining / timePerResponse`

#### Scenario: Round-time bar hidden on non-time-limited levels
- **WHEN** rendering a level with `hasTimeLimit == false` OR `isNonPunitiveRefresh == true`
- **THEN** no round-time bar is rendered

### Requirement: No per-level cosmic background image

The gameplay screen SHALL NOT render the v1 per-level `Image("Level\(currentLevel)")` cosmic backgrounds. The screen background SHALL be `Theme.Colors.background` (pure black). The tap burst animation provides the dynamic visual element.

#### Scenario: Background is plain black
- **WHEN** auditing the redesigned active gameplay portion of `LevelGameView`
- **THEN** no `Image("Level…")` reference appears in the body; the outer ZStack background is `Theme.Colors.background.ignoresSafeArea()`

### Requirement: Visual fidelity to design system

Every visual constant on the active gameplay screen SHALL come from the design-system primitives. Hex literals, hard-coded font names, raw point spacing, gradient text on the level title, and emoji acting as visual icons SHALL NOT appear in the redesigned active gameplay body.

#### Scenario: No raw style literal
- **WHEN** auditing the redesigned active gameplay portion of `LevelGameView`
- **THEN** every color comes from `Theme.Colors.*`, every font from `Font.cr*`, every spacing/radius from `Theme.Spacing.*` / `Theme.Radius.*`

#### Scenario: Game logic untouched
- **WHEN** comparing the diff
- **THEN** all game-state methods (`handleTileTap`, `startLevel`, `endGameSession`, scoring helpers, timer tick handlers, level-complete / fail transitions) are NOT modified; `LevelSystemModels.swift`, `Tile.swift`, and every other gameplay-state file is also unchanged

### Requirement: Existing overlays preserved

The wrong-tap red error flash, the streak animation, and the level-intro modal overlays SHALL continue to render unchanged when their existing trigger conditions are met. Their integration with the active gameplay layout SHALL remain functional.

#### Scenario: Error flash on wrong tap
- **WHEN** the user taps a wrong tile and the existing logic sets `showingErrorFlash = true`
- **THEN** the red flash overlay renders over the gameplay screen exactly as in v1

#### Scenario: Streak animation
- **WHEN** the user reaches a streak that triggers `showStreakAnimation = true`
- **THEN** the streak animation overlay renders exactly as in v1

#### Scenario: Level-intro modal
- **WHEN** `showLevelIntro` becomes true at the start of a level
- **THEN** the redesigned `LevelIntroView` renders over the gameplay screen exactly as previously shipped
