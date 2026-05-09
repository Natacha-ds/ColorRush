## Why

Each level inside `LevelGameView` is preceded by a `LevelIntroView` modal that auto-dismisses after 3 seconds (or earlier if the user taps the close X, which actually behaves as a "skip"). The modal's v1 visual — pink "Targeted score" card on a translucent black bg, decorative stars, bomb-icon description — is light-themed, doesn't match the redesign, and confuses the role of the X (looks like cancel, behaves like skip). Frame 4 redesigns this surface: dark dialog, "LEVEL XX - WARM UP" subtitle, "BEAT N" headline with the target tinted cyan, two side-by-side TIME and LIVES summary cards, a centered PLAY button, and a thin timer line at the top visualizing the 3-second auto-dismiss countdown. The X is dropped — there's nothing to cancel from this modal once the user reaches it; PLAY (or waiting for the timer) is the only forward path.

## What Changes

- Rewrite `LevelIntroView` (currently inline in `LevelGameView.swift` at lines ~1454-1602) using design-system primitives. The struct stays in the same file — no extraction, no rename — to keep this change scoped to the visual surface.
- Replace the v1 layout (stars, pink card, bomb description, X button) with the Frame 4 layout: dark rounded surface centered on a translucent backdrop, contents stacked top-to-bottom: timer line, "LEVEL XX - WARM UP" small label, "BEAT N" big headline, HStack of TIME card + LIVES card, PLAY button.
- **Drop the X close button** entirely. The "skip" affordance is now the explicit PLAY button at the bottom of the modal.
- **Add a thin timer line** at the top of the modal (~3pt tall, full modal width, gradient `Theme.Gradient.primary` violet→cyan) that animates from 100% to 0% over 3 seconds, visually mirroring the parent's `pendingIntroDismiss` DispatchWorkItem countdown.
- The "LEVEL XX - WARM UP" subtitle uses the warm-up suffix only for levels 1 and 2 (matches the existing `levelDescription` rule for those levels). Other levels show "LEVEL XX" alone — the v1 description copy ("Colors will change every second", "You have Xs to tap fast or lose 5 pts!") is dropped from this modal; that information lives in the gameplay HUD if needed.
- Read level data from the existing `LevelRun` API: `levelRun.currentLevel`, `levelRun.getRequiredScore()`, `levelRun.currentLevelConfig?.durationSeconds`, `levelRun.remainingLives`, `levelRun.mistakeTolerance.totalLives`. No game-state changes.
- **No changes** to `LevelGameView.startLevel()`, `dismissLevelIntroAndStart()`, the 3.0-second `DispatchWorkItem`, or any other gameplay-side logic. The timer line is purely visual; the auto-dismiss is still driven by the parent.

## Capabilities

### New Capabilities
- `level-intro-modal`: View-layer contract for the redesigned per-level intro modal — what it displays, how the timer line behaves, and how it composes with the existing parent's auto-dismiss timer.

### Modified Capabilities
<!-- None. Game state, run lifecycle, and the parent's auto-dismiss DispatchWorkItem are unchanged. -->

## Impact

- **Modified**: `ColorGame/LevelGameView.swift` — only the inline `LevelIntroView` struct (≈148 lines, lines 1454-1602) is rewritten. The rest of the 2598-line file is untouched.
- **Unchanged**: `LevelSystemModels.swift`, `LevelRun.startLevel()` lifecycle, `dismissLevelIntroAndStart()`, `pendingIntroDismiss` mechanics, score / lives / timer state.
- **No new dependencies**: pure SwiftUI, consumes only design-system primitives (`Theme.*`, `Font.cr*`, `.crPrimary`).
