## ADDED Requirements

### Requirement: Per-tap timer banner

When the level being introduced has a non-nil `timePerResponse` in its `LevelConfig` (levels 3 and above), the level-intro modal SHALL render a yellow lightning-bolt banner between the TIME/LIVES card row and the PLAY button. The banner SHALL contain a yellow lightning icon (`CRLightning` template asset tinted `Theme.Colors.warning`) and a localized text in the form `X seconds max per tap!` (`X second max per tap!` for the 1.0 case), where `X` is the per-tap timer value sourced from `currentLevelConfig.timePerResponse`. Levels 1 and 2 (no per-tap timer) SHALL NOT render the banner; their modal layout is unchanged.

#### Scenario: Level 3 banner
- **WHEN** the modal renders for `levelRun.currentLevel == 3` (timePerResponse == 1.8)
- **THEN** a yellow lightning-bolt banner is visible between the TIME/LIVES row and the PLAY button, with text "1.8 seconds max per tap!" (EN) or "1,8 secondes max par coup !" (FR)

#### Scenario: Level 5 banner
- **WHEN** the modal renders for `levelRun.currentLevel == 5` (timePerResponse == 1.5)
- **THEN** the banner shows "1.5 seconds max per tap!" / "1,5 secondes max par coup !"

#### Scenario: Level 9 banner — singular second
- **WHEN** the modal renders for `levelRun.currentLevel == 9` (timePerResponse == 1.0)
- **THEN** the banner shows "1 second max per tap!" / "1 seconde max par coup !" — note "second" (singular) in EN; FR keeps "seconde" singular at 1.

#### Scenario: Level 1 banner absent
- **WHEN** the modal renders for `levelRun.currentLevel == 1` (timePerResponse == nil)
- **THEN** no banner is rendered between the card row and the PLAY button; the layout matches the pre-change spec (TIME/LIVES → PLAY directly)

#### Scenario: Banner uses design tokens
- **WHEN** auditing the per-tap timer banner code
- **THEN** the icon tint is `Theme.Colors.warning`, the text font is a `Font.cr*` token, and spacing/radius come from `Theme.Spacing.*` / `Theme.Radius.*` — no hex literal, no raw point spacing
