# level-intro-modal Specification

## Purpose
TBD - created by archiving change level-intro-modal-redesign. Update Purpose after archive.
## Requirements
### Requirement: Modal layout

The level-intro modal SHALL render, on a semi-transparent black backdrop, a centered dark rounded surface containing the following elements stacked vertically: a thin animated timer line at the top, a small "LEVEL XX - WARM UP" subtitle, a "BEAT N" big headline, an HStack of two stats cards (TIME and LIVES), and a primary PLAY button at the bottom. The modal SHALL match Frame 4.

#### Scenario: Modal appears
- **WHEN** the parent sets `showLevelIntro = true` for the start of a level
- **THEN** the modal becomes visible centered on screen, with a semi-transparent black backdrop covering the rest of the view, and the timer line begins depleting from full width to zero over 3 seconds

#### Scenario: Modal disappears
- **WHEN** the parent sets `showLevelIntro = false` (either via the auto-dismiss `DispatchWorkItem` after 3 seconds or via the user tapping PLAY which calls `onDismiss`)
- **THEN** the modal is removed from the view hierarchy

### Requirement: No close button

The level-intro modal SHALL NOT include an X close button. The PLAY button at the bottom SHALL be the only user-initiated dismissal action; otherwise the modal auto-dismisses after the parent's 3-second timer.

#### Scenario: No X in the modal
- **WHEN** auditing the redesigned `LevelIntroView` body
- **THEN** there is no `Image(systemName: "xmark")` or any other close-icon button rendered in the modal

#### Scenario: PLAY skips the wait
- **WHEN** the user taps the PLAY button while the modal is visible
- **THEN** the `onDismiss` closure is invoked synchronously, the modal disappears, and the level starts immediately (existing parent behavior unchanged)

### Requirement: Timer line

The level-intro modal SHALL render a thin (≤4pt tall) horizontal timer line at the top of the modal surface, filled with `Theme.Gradient.primary` (violet→cyan), whose visible width animates from 100% of the modal width to 0% over a 3-second duration starting on appearance. The animation SHALL use a linear easing.

#### Scenario: Timer animates on appear
- **WHEN** the modal renders for the first time after a level starts
- **THEN** the timer line begins at full width and visibly depletes to zero over approximately 3 seconds with linear easing

#### Scenario: Timer is decoupled from auto-dismiss
- **WHEN** comparing the timer line implementation to the parent's `DispatchWorkItem` for auto-dismiss
- **THEN** the timer line is driven by a local `@State` and `withAnimation(.linear(duration: 3.0))`, not by any binding to the parent's countdown; both run independently with the same intended duration

### Requirement: Subtitle copy

The subtitle SHALL read "LEVEL XX - WARM UP" for levels 1 and 2 (matching the v1 warm-up rule) and "LEVEL XX" alone for levels 3 and above. Level numbers SHALL be zero-padded to two digits.

#### Scenario: Level 1 subtitle
- **WHEN** the modal renders for `levelRun.currentLevel == 1`
- **THEN** the subtitle text is "LEVEL 01 - WARM UP" rendered in `.crLabel` style and `Theme.Colors.textSecondary`

#### Scenario: Level 5 subtitle
- **WHEN** the modal renders for `levelRun.currentLevel == 5`
- **THEN** the subtitle text is "LEVEL 05" with no warm-up suffix

### Requirement: Beat headline

The "BEAT N" headline SHALL display the required score for the current level, sourced from `levelRun.getRequiredScore()`. The "BEAT" word SHALL render in `Theme.Colors.textPrimary` (white) and the score number in `Theme.Colors.accentSecondary` (cyan), per Frame 4.

#### Scenario: Beat headline rendered
- **WHEN** the modal renders for a level with required score 250
- **THEN** the headline shows "BEAT 250" with "BEAT" in white and "250" in cyan, in `.crDisplay` style

### Requirement: TIME card

The TIME card SHALL render a small "TIME" uppercase label and the level's duration formatted as `MM:SS` with zero-padded minutes and seconds. The duration source SHALL be `levelRun.currentLevelConfig?.durationSeconds`. If the config is unavailable, the card SHALL display "—:—" or be hidden.

#### Scenario: 30-second level
- **WHEN** the modal renders for a level with `durationSeconds == 30`
- **THEN** the TIME card shows "TIME" + "00:30"

#### Scenario: 90-second level
- **WHEN** the modal renders for a level with `durationSeconds == 90`
- **THEN** the TIME card shows "TIME" + "01:30"

### Requirement: LIVES card

The LIVES card SHALL render a small "LIVES" uppercase label and a horizontal hearts row sized to `levelRun.mistakeTolerance.totalLives`, where the first `levelRun.remainingLives` hearts are filled with `Theme.Colors.danger` and the remaining ones are dimmed at `Theme.Colors.danger.opacity(0.18)`.

#### Scenario: Full lives at level start
- **WHEN** the modal renders for a Rookie run at level 1 with no lives lost yet (`remainingLives == 5`, `totalLives == 5`)
- **THEN** the LIVES card shows "LIVES" + 5 fully filled hearts

#### Scenario: Mid-run with lives lost
- **WHEN** the modal renders for a Rookie run with 3 lives remaining out of 5 (`remainingLives == 3`, `totalLives == 5`)
- **THEN** the LIVES card shows "LIVES" + 3 filled hearts followed by 2 dimmed hearts

### Requirement: PLAY button

The modal SHALL include a centered PLAY button at the bottom using the design system's primary CTA style. Tapping the button SHALL invoke the `onDismiss` closure, identical in effect to the auto-dismiss after 3 seconds.

#### Scenario: PLAY button uses primary style
- **WHEN** the modal renders
- **THEN** the PLAY button is styled with `.buttonStyle(.crPrimary)` and labeled "Play" with a play-arrow SF symbol icon

#### Scenario: PLAY tap dismisses
- **WHEN** the user taps PLAY while the auto-dismiss timer is mid-animation
- **THEN** `onDismiss` is invoked, the modal disappears, and the parent's auto-dismiss `DispatchWorkItem` (which would have fired later) is harmlessly no-op'd because `showLevelIntro` is already `false`

### Requirement: Visual fidelity to design system

Every visual constant on the level-intro modal SHALL come from the design-system primitives. Hex literals, hard-coded font names, hard-coded spacing / radius values, and decorative emoji or images (stars, bomb) SHALL NOT appear in the redesigned `LevelIntroView` body.

#### Scenario: No raw style literal in the modal
- **WHEN** auditing the redesigned `LevelIntroView` after this change
- **THEN** every color comes from `Theme.Colors.*`, every font from `Font.cr*`, every spacing/radius from `Theme.Spacing.*` / `Theme.Radius.*`, and no decorative star, bomb, or emoji image is rendered

#### Scenario: Game logic untouched
- **WHEN** comparing the diff
- **THEN** `LevelGameView`'s `startLevel()`, `dismissLevelIntroAndStart()`, `pendingIntroDismiss` mechanics, and any other gameplay-state code in the file (outside the inline `LevelIntroView` struct) are not modified

