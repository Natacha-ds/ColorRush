## Context

`LevelSystemSelectionView` v1 is a 332-line file implementing the two-step picker that runs after PLAY on Home. Its state machine (`SelectionStep.gameType` then `.mistakeTolerance`), back-arrow handling, default difficulty pre-selection (`.easy`), and the way it instantiates a `LevelRun` and pushes `LevelGameView` on game start are all sound. The visuals are v1 — light theme, white cards, chevron rows on auto-advance, emoji rocket "Start now!" button.

The new design (Frames 2 + 3) keeps the same two-step structure and same per-step purpose but redesigns every visual element: dark theme, brand-typed step labels, design-system cards, hearts visualization on difficulty cards, explicit "CONTINUE" / "LET'S GO" CTAs, conditional "Recommended to start" chip on Color ONLY for new users.

Constraints:
- Pure SwiftUI, no third-party.
- Must consume only design-system primitives in the view layer (`Theme.*`, `Font.cr*`, `CRCard`, `CRChip`, `CRSectionHeader`, `.crPrimary` button style).
- Must not modify game logic (`LevelRun`, enums in `LevelSystemModels.swift`).
- iOS 26+, can use `.preferredColorScheme(.dark)` and modern transitions.

## Goals / Non-Goals

**Goals:**
- Migrate `LevelSystemSelectionView` to Frames 2 + 3 1:1.
- Preserve every game-state behavior: pre-selected `.easy`, auto-advance from mode to difficulty (now via CONTINUE button instead of immediate tap), back navigation, `LevelRun.startRun(...)` called only when both selections exist and user taps LET'S GO, full-screen cover to `LevelGameView`.
- Add the conditional "Recommended to start" chip rule based on the user's local Color+Text history.

**Non-Goals:**
- Modify `LevelRun`, `LevelSystemModels`, `LevelGameView`, or any leaderboard / GC code.
- Move the `RulesView` access — it stays referenced from nowhere in the new picker; we'll re-home it in a later UX-focused change.
- Add per-card icons or asset images beyond what Frame 2 / Frame 3 strictly show.
- Animate the swatches inside the mode cards (they're static color squares per Frame 2).

## Decisions

### Decision 1: "Recommended to start" — derived from `LeaderboardStore`

The chip appears on the Color ONLY card iff the user has zero scores in **any** `(.colorAndText, *)` bucket:

```swift
private var shouldRecommendColorOnly: Bool {
    MistakeTolerance.allCases.allSatisfy { tolerance in
        LeaderboardStore.shared.getScores(
            gameType: .colorAndText,
            mistakeTolerance: tolerance
        ).isEmpty
    }
}
```

The store is observed via `@StateObject` (already injected in v1), so the chip naturally hides if the user finishes a Color+Text level and reopens the picker.

**Why:** uses the existing single source of truth for "has the user completed this mode"; no new persistence; reactive by default; chip lifecycle bound to actual play history.

**Alternative considered:** a separate `@AppStorage` flag like `hasSeenRecommendation`. Rejected — invents a new persistence axis when the existing scores already encode the same answer.

### Decision 2: Step indicator — text label, not dots

Use `CRSectionHeader(title:, step:, onBack:)` already shipped in the design-system foundation. The step parameter renders "STEP 1/2" or "STEP 2/2" above the title; the back button is co-located.

**Why:** matches Frame 2 / Frame 3's text label exactly; avoids re-implementing v1's progress dots; reuses an existing component.

### Decision 3: Step 1 — explicit CONTINUE button (no auto-advance)

V1 advances to step 2 the moment the user taps a mode card. V2 follows Frame 2 by separating selection from advancement: tapping a card sets `selectedGameType` (visual selection state), and advancing requires an explicit CONTINUE tap. This is consistent with Frame 2's prominent CONTINUE CTA.

**Why:** matches the design; avoids accidental advances on quick scrolls/taps; gives the user a beat to read the description before committing.

**Alternative considered:** keep auto-advance and ignore the CONTINUE button shown in the design. Rejected — the design is explicit about it being a two-tap flow.

### Decision 4: Mode card swatches — inline mini grids

Frame 2 mode cards each show a 2×2 swatch grid:
- Color ONLY: bare red / blue / green / yellow tiles using `Theme.Colors.Tile.*`
- Color and Text: same tiles but each rendered with a contrasting word label inside ("BLUE" on red, "RED" on blue, "GREEN" on green, "RED" on yellow — i.e., word ≠ color, the gameplay quirk)

Implemented as an inline private subview (`ModeSwatchGrid(showsLabels: Bool)`). No new shared design-system component — the only screen using these swatches is this picker.

**Why:** YAGNI — this layout pattern is exclusive to this picker; no value in extracting until / unless a second screen needs it.

### Decision 5: Difficulty card hearts — inline subview

Frame 3 difficulty cards show a row of red hearts on the right (5 / 3 / 1). Implemented as an inline `HeartsRow(count: Int)` subview using SF Symbol `heart.fill` tinted `Theme.Colors.danger`.

**Why:** also a one-screen pattern; trivial to inline; consistent with the "no premature shared component" stance.

### Decision 6: Card selection state

Selected mode card: cyan accent border (`Theme.Colors.accentSecondary`).
Selected difficulty card: difficulty-specific border per Frame 3 — green for Rookie (`Theme.Colors.success`), gold for Pro (`Theme.Colors.pro`), red for Insane (`Theme.Colors.danger`). The design uses these colours as small left-edge accent strips and as the card's full border when selected. We render a 2pt `strokeBorder` in the difficulty's tone when selected and a subtle `Theme.Colors.border` when not.

### Decision 7: Brand labels in private view extensions

Same pattern as `LeaderboardView`:
```swift
private extension MistakeTolerance {
    var brandLabel: String { … }    // ROOKIE / PRO / INSANE
    var difficultyTone: Color { … } // success / pro / danger
}
```

Difficulty tone is also bundled here so the card colour cue stays close to the brand label.

### Decision 8: Drop "How to play?" link, keep RulesView code

Frame 3 doesn't show a rules entry. We remove the link + `fullScreenCover` from this picker. `RulesView.swift` and its initializer are untouched; a future change will surface rules elsewhere (Settings or long-press on PLAY — both un-designed in Figma yet).

**Why:** ship the design as-drawn; rules access is a UX concern best owned by a dedicated future change with its own design input.

## Risks / Trade-offs

- **[Risk]** Removing the "How to play?" link reduces discoverability of game rules for new users between this change and whenever rules are re-homed → **Mitigation:** the picker's two cards include short rule-of-thumb descriptions (Frame 2 design copy) which are sufficient for the core mechanic; full rules can wait for the dedicated re-home change.
- **[Risk]** The "Recommended to start" recommendation depends on local-only data; a user who plays Color+Text only on a fresh device or after a re-install would re-see the chip → accepted: same data lifecycle as the rest of the local leaderboard, consistent.
- **[Risk]** Switching from auto-advance to CONTINUE adds a tap to the flow → accepted: matches the explicit design intent; users barely notice.
- **[Trade-off]** Inline subviews (mode swatches, hearts row) duplicate logic that could be extracted → accepted, see Decisions 4 + 5.

## Migration Plan

1. Rewrite `LevelSystemSelectionView.swift` body and inline subviews using design-system primitives.
2. Add private brand-label / tone extensions for `GameType` and `MistakeTolerance`.
3. Verify in Xcode preview (mode step + difficulty step + chip on/off states).
4. Build, unit tests (`-only-testing:ColorGameTests -parallel-testing-enabled NO`).
5. Manual sim verification: PLAY from Home, both steps render, back navigation works, CONTINUE only when a mode is picked, LET'S GO opens game.

Rollback: revert the single file. Game logic and surrounding screens are untouched.

## Open Questions

- The "Recommended to start" chip wording: localized? In v1 the strings are emoji-prefixed and localized via `Localizable.xcstrings`. The new chip text is short and English-only at first; localization can be added when the FR/EN sweep is revisited (the previous i18n change archived didn't cover this future copy).
- Card press feedback — Frame 2 / Frame 3 don't show a pressed state; we apply a default `.scaleEffect(0.98)` on press to stay consistent with the rest of the design system. Tunable.
