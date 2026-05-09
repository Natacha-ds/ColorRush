## Context

`LevelIntroView` is a SwiftUI view embedded as an overlay (not a sheet) inside `LevelGameView`'s body, conditionally rendered when `showLevelIntro == true`. The parent's `startLevel()` sets the flag and schedules a `DispatchWorkItem` to flip it back to `false` after 3 seconds — the modal "auto-plays" the level. The v1 modal's X button calls `onDismiss`, which in `LevelGameView` is wired to `dismissLevelIntroAndStart()`, so the X is functionally equivalent to PLAY (skip-the-wait), not a cancel.

Frame 4 redesigns the surface to match the rest of the dark theme. The behavior contract stays the same: 3-second auto-PLAY with a manual skip via the PLAY button.

Constraints:
- Pure SwiftUI, no third-party.
- Must consume only design-system primitives.
- Must NOT modify game state machinery — `startLevel()`, `pendingIntroDismiss`, `dismissLevelIntroAndStart()` stay as-is.
- iOS 26+, can use `withAnimation(.linear(duration: 3.0))` for the timer line.

## Goals / Non-Goals

**Goals:**
- Migrate `LevelIntroView` to Frame 4 1:1 within the same source file (no extraction).
- Drop the X close button and replace its "skip" affordance with the explicit PLAY button.
- Add a thin animated timer line at the top of the modal that visually tracks the 3-second auto-dismiss.
- Source all displayed data from the existing `LevelRun` API.

**Non-Goals:**
- Modify the parent's auto-dismiss timing or its DispatchWorkItem mechanics.
- Add cancellation (no swipe-down, no back button, no escape — the modal is a one-way checkpoint).
- Repurpose or relocate the legacy v1 description copy ("Colors will change every second" etc.) — it's dropped from this surface; if needed in the gameplay HUD, that's a separate concern.
- Extract `LevelIntroView` to its own file.

## Decisions

### Decision 1: Timer line is purely visual

The timer line uses a SwiftUI implicit animation (`withAnimation(.linear(duration: 3.0))`) tied to a `@State` `progress` variable that flips from 1.0 to 0.0 on `.onAppear`. The parent's actual auto-dismiss timing is unchanged — the visual timer is just a UI cue, not a control of the lifecycle.

```swift
@State private var progress: Double = 1.0

// On appear:
withAnimation(.linear(duration: 3.0)) {
    progress = 0.0
}
```

The line's width fills the modal's width × `progress`. When the parent flips `showLevelIntro = false`, the modal disappears, the SwiftUI state is destroyed, and the next presentation starts fresh.

**Why:** zero coupling to game state; if the parent ever changes the auto-dismiss duration, we update the constant in one place (the `.linear(duration:)`).

**Alternative considered:** drive the line from a published `progress` on `LevelRun`. Rejected — adds game-state surface area for a purely visual concern.

### Decision 2: PLAY button replaces the X

The PLAY button sits at the bottom of the modal and calls the same `onDismiss` closure that the v1 X button called. The parent wires this to `dismissLevelIntroAndStart()` (skip-the-wait). No new wiring needed in `LevelGameView`.

### Decision 3: Modal layout — single VStack with a timer line at the top

```
ZStack
  Color.black.opacity(0.6)  // backdrop
  VStack(spacing: …)
    timerLine                       // 3pt thick, gradient, fills width × progress
    "LEVEL 01 - WARM UP" label      // small uppercase, textSecondary
    "BEAT 250" display              // big bold italic, "250" tinted cyan
    HStack(spacing: …)              // stats row
      TimeCard                      // CRCard, "TIME" label + "00:30" display
      LivesCard                     // CRCard, "LIVES" label + hearts row
    Spacer (small)
    Button("Play") {…}              // .crPrimary
  .padding(…)
  .background(Theme.Colors.surface, in: RoundedRectangle(...))
```

The modal's outer VStack is wrapped in a fixed `.frame(maxWidth: 320)` to keep it compact and centered.

### Decision 4: TIME format — MM:SS with leading zeros

`levelConfig.durationSeconds` is an `Int`; formatted as `String(format: "%02d:%02d", duration / 60, duration % 60)`. For a 30-second level: "00:30".

### Decision 5: LIVES card — full hearts row colored / dimmed by remaining count

Render `mistakeTolerance.totalLives` slots; the first `remainingLives` are filled `Theme.Colors.danger`, the rest are dimmed `Theme.Colors.danger.opacity(0.18)` (mirrors the `CRHeartsPill` pattern from the gameplay HUD). This way the user sees both the max for this difficulty and what they have right now.

**Alternative considered:** show just the count as a number. Rejected — Frame 4 explicitly draws hearts.

### Decision 6: Subtitle suffix — warm-up only on levels 1-2

```swift
private var subtitle: String {
    let levelStr = String(format: "Level %02d", levelRun.currentLevel)
    if levelRun.currentLevel == 1 || levelRun.currentLevel == 2 {
        return "\(levelStr) - Warm up"
    }
    return levelStr
}
```

For levels 3+ we drop the suffix. The v1 had per-level descriptions for higher levels; those are dropped from this modal.

**Alternative considered:** show the v1 per-level description as the subtitle. Rejected — Frame 4 design copy is just "LEVEL 01 - WARM UP"; we follow the design.

### Decision 7: Backdrop tap is ignored

The semi-transparent black backdrop does not respond to taps (no `.onTapGesture` to dismiss). The user must tap PLAY or wait for the timer. This matches the v1 behavior (the v1 backdrop also wasn't tappable; only the X dismissed).

## Risks / Trade-offs

- **[Risk]** The visual timer line and the parent's actual auto-dismiss could drift out of sync if the parent's `3.0` constant ever changes → **Mitigation:** define a shared constant `Self.autoPlayDuration: TimeInterval = 3.0` at the top of `LevelIntroView` and consume it from both `withAnimation` and (eventually) the parent. For this change we keep the constant local to the modal and document the expectation; updating both call sites if the duration ever changes is a one-line change.
- **[Risk]** Dropping the X removes the only "explicit close" affordance → accepted: PLAY is now the explicit forward action; the user committed to playing when they tapped LET'S GO on the difficulty picker.
- **[Trade-off]** Timer line animation runs on every level intro (10 levels per run × possibly multiple runs) → negligible; SwiftUI implicit animations on a single CGFloat are cheap.

## Migration Plan

1. Replace the v1 `LevelIntroView` struct body in `LevelGameView.swift` (lines ~1454-1602) with the new Frame 4 implementation.
2. Verify in Xcode preview (use a mock `LevelRun` initializer to render with sample data).
3. Build, unit tests (`-only-testing:ColorGameTests -parallel-testing-enabled NO`).
4. Manual sim verification: tap PLAY → mode → difficulty → LET'S GO → modal renders for 3s with timer depleting → game starts. Tap PLAY in modal → game starts immediately.

Rollback: revert the single struct's body. The parent's `startLevel()` mechanics are untouched.

## Open Questions

- The v1 description for levels 9-10 ("Colors will change every second") and for levels 3-8 (per-config details) is currently dropped from this modal. If Tony wants to surface that copy somewhere, the gameplay HUD or a one-time tooltip could host it — out of scope here, flag for follow-up.
- Should the timer line have a slight pulse / shimmer? Skipping for V1 — keep it simple (linear deplete). Easy to add later.
