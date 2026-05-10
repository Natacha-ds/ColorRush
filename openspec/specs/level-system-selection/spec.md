# level-system-selection Specification

## Purpose
TBD - created by archiving change level-system-selection-redesign. Update Purpose after archive.
## Requirements
### Requirement: Two-step picker layout

The level-system selection screen SHALL present a two-step flow on a black background, matching Frames 2 and 3:
- Step 1 ("PICK A MODE"): a "STEP 1/2" small label, a back arrow, the "PICK A MODE" headline, two stacked mode cards (Color ONLY, Color and Text), and a "CONTINUE" CTA at the bottom.
- Step 2 ("HOW HARD?"): a "STEP 2/2" small label, a back arrow, the "HOW HARD?" headline, three stacked difficulty cards (ROOKIE, PRO, MASTER), and a "LET'S GO" CTA at the bottom.

#### Scenario: Default state on first open
- **WHEN** the user taps PLAY on Home for the first time
- **THEN** the picker opens on Step 1, no mode is pre-selected, the CONTINUE button is rendered visually disabled

#### Scenario: Mode tap selects without advancing
- **WHEN** the user taps the Color ONLY card on Step 1
- **THEN** the Color ONLY card renders with a cyan (`Theme.Colors.accentSecondary`) selection border, the CONTINUE button becomes enabled, and the screen STAYS on Step 1 (no auto-advance)

#### Scenario: CONTINUE advances to Step 2
- **WHEN** the user taps CONTINUE while a mode is selected
- **THEN** the screen transitions to Step 2 with `MistakeTolerance.easy` pre-selected (Rookie card highlighted with green border)

#### Scenario: Back from Step 2 returns to Step 1 preserving selection
- **WHEN** the user taps the back arrow on Step 2
- **THEN** the screen returns to Step 1 and the previously selected mode is still visually selected

#### Scenario: Back from Step 1 dismisses the picker
- **WHEN** the user taps the back arrow on Step 1
- **THEN** the picker is dismissed and the user returns to the Home screen

### Requirement: Mode card content

Each mode card SHALL display: a 2×2 mini-swatch grid (top-left corner area), the card title in headline style ("Color ONLY" / "Color and Text"), and a short description below the title. The Color ONLY card's swatch grid SHALL show four bare brand-tile colors (`Theme.Colors.Tile.red`, `.blue`, `.green`, `.yellow`). The Color and Text card's swatch grid SHALL show the same four tiles each with a contrasting word label inside (the word displayed SHALL NOT match the tile color, illustrating the gameplay quirk).

#### Scenario: Color ONLY card swatches
- **WHEN** the Color ONLY card renders
- **THEN** the swatch grid shows four solid color tiles using `Theme.Colors.Tile.*` with no inner text

#### Scenario: Color and Text card swatches
- **WHEN** the Color and Text card renders
- **THEN** the swatch grid shows the same four tiles each with a single word label inside whose meaning differs from the tile's color

### Requirement: Recommended-to-start chip

The Color ONLY card SHALL display a "Recommended to start" chip in its top-right corner if and only if the user has zero recorded local scores in any `(GameType.colorAndText, *)` bucket. The chip SHALL hide as soon as the user records at least one score in any Color+Text bucket.

#### Scenario: New user sees the chip
- **WHEN** the user opens the picker and `LeaderboardStore.shared.getScores(gameType: .colorAndText, mistakeTolerance: t)` returns an empty array for every `t`
- **THEN** the Color ONLY card shows a "Recommended to start" chip in its top-right corner

#### Scenario: Returning user does not see the chip
- **WHEN** the user opens the picker and `LeaderboardStore.shared.getScores(gameType: .colorAndText, mistakeTolerance: t)` returns at least one entry for at least one `t`
- **THEN** the Color ONLY card does NOT show the chip

### Requirement: Difficulty card content

Each difficulty card SHALL display: the brand label (ROOKIE / PRO / MASTER) in headline style, a short description ("5 lives - good to start" / "3 lives - the real deal" / "1 life - 1 mistake, game over"), and a horizontally laid-out row of red filled hearts (`heart.fill`, `Theme.Colors.danger`) whose count equals the tolerance's `totalLives` (5, 3, 1).

#### Scenario: Rookie card hearts
- **WHEN** the ROOKIE card renders
- **THEN** the right side of the card shows 5 red filled hearts

#### Scenario: Pro card hearts
- **WHEN** the PRO card renders
- **THEN** the right side of the card shows 3 red filled hearts

#### Scenario: Master card hearts
- **WHEN** the MASTER card renders
- **THEN** the right side of the card shows 1 red filled heart

### Requirement: Difficulty card selection tone

The selected difficulty card SHALL render with a 2pt `strokeBorder` in the difficulty's tone color and a small left-edge accent strip in the same color: `Theme.Colors.success` for Rookie (green), `Theme.Colors.pro` for Pro (gold), `Theme.Colors.danger` for Master (red). Non-selected difficulty cards SHALL render with a subtle `Theme.Colors.border` 1pt stroke.

#### Scenario: Rookie selected
- **WHEN** the user selects the ROOKIE card
- **THEN** the card border is rendered in `Theme.Colors.success` at 2pt and a left-edge strip in the same color is visible; PRO and MASTER cards render with a subtle 1pt `Theme.Colors.border`

#### Scenario: Pro selected
- **WHEN** the user selects the PRO card
- **THEN** the PRO card border is rendered in `Theme.Colors.pro` at 2pt and the left-edge strip is gold

#### Scenario: Master selected
- **WHEN** the user selects the MASTER card
- **THEN** the MASTER card border is rendered in `Theme.Colors.danger` at 2pt and the left-edge strip is red

### Requirement: Game start

When the user taps LET'S GO on Step 2 with both a mode and a difficulty selected, the picker SHALL configure the existing `LevelRun` state object via `LevelRun.startRun(gameType:mistakeTolerance:)` (unchanged from v1) and SHALL present `LevelGameView` as a full-screen cover (unchanged from v1).

#### Scenario: Valid game start
- **WHEN** the user has selected a mode and a difficulty and taps LET'S GO
- **THEN** `LevelRun.startRun(gameType:, mistakeTolerance:)` is invoked with the selected values and `LevelGameView` is presented as a full-screen cover

#### Scenario: How-to-play link is not present
- **WHEN** auditing Step 2 of the redesigned picker
- **THEN** there is no "How to play?" link and `RulesView` is not presented from this screen (RulesView itself remains in the codebase, untouched)

### Requirement: Visual fidelity to design system

Every visual constant on the level-system selection screen SHALL come from the design-system primitives. Hex literals, hard-coded font names, hard-coded spacing / radius values, and emoji used as visual icons (rocket, chevron, etc.) SHALL NOT appear in `LevelSystemSelectionView.swift` after this change. Existing `GameType.displayName` and `MistakeTolerance.displayName` SHALL NOT be modified.

#### Scenario: No raw style literal in the view
- **WHEN** auditing `LevelSystemSelectionView.swift` after this change
- **THEN** every color comes from `Theme.Colors.*`, every font from `Font.cr*`, every spacing/radius from `Theme.Spacing.*` / `Theme.Radius.*`, and no emoji acts as a visual layout icon

#### Scenario: Game logic untouched
- **WHEN** comparing the diff
- **THEN** `LevelSystemModels.swift`, `LevelGameView.swift`, `RulesView.swift`, `HomeView.swift`, and `MainTabView.swift` are not modified

### Requirement: Difficulty raw values are stable

The display label for the hardest tier SHALL be `MASTER`, but the underlying `MistakeTolerance.hard` raw value, total-lives count (1), and tone color (`Theme.Colors.danger`) SHALL NOT be modified. Existing local scores and Game Center buckets keyed under the prior `INSANE` label SHALL continue to load and rank under the new label without migration.

#### Scenario: Pre-existing INSANE-bucket scores survive the rename
- **WHEN** a user with v1 local scores in the prior `INSANE` bucket opens the leaderboard after the rename ships
- **THEN** those scores are listed under the `MASTER` label without being lost or duplicated; `LeaderboardStore.getScores(gameType:, mistakeTolerance: .hard)` returns the same entries it returned pre-rename

#### Scenario: Game Center bucket key is unchanged
- **WHEN** a score is submitted on the hardest tier
- **THEN** `GameCenterService` submits to the same leaderboard ID it used pre-rename (no migration), preserving rank continuity for existing players

### Requirement: French mode card descriptions

The FR localization of the two mode-card descriptions SHALL match the canonical wording defined for v1 polish:
- Color ONLY → `Une couleur est annoncée. Tape sur n'importe quel carré qui n'est pas de cette couleur.`
- Color and Text → `Chaque carré a une couleur et un mot. Tape seulement quand ni l'un ni l'autre ne correspond à la couleur annoncée.`

#### Scenario: French device reads the picker
- **WHEN** the picker renders on a device with the FR locale active
- **THEN** the Color ONLY card body shows the FR string above; the Color and Text card body shows its FR string above; both are sourced from `Localizable.xcstrings` with `state: "translated"`

