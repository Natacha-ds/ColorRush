## Why

When the player chains correct taps to a streak milestone (10/20/30 in Color Only, every 5 in Color+Text), the animation overlay reads "🔥 Streak +20 pt". The bonus points have already been added to `currentScore` by the time the animation appears, so the "+20 pt" label is read by players as "20 more points are coming on top of what you see". The score never grows by that extra amount, leaving the player confused about whether streak bonuses are double-counted, miscounted, or eaten silently.

Reframing the animation as an achievement count ("10 in a row!") removes the ambiguity, replaces a misleading number with a motivating one, and keeps the celebratory feel without lying about score math.

## What Changes

- Rename the `@State` variable that drives the animation from `streakBonusAmount` to `streakDisplayCount` to reflect the new semantic.
- In the `.onChange(of: levelRun.lastBonusEarned)` handler, capture `levelRun.currentStreak` (the streak count at the moment of the milestone) instead of the bonus delta.
- Update `StreakAnimationView`'s parameter from `bonusAmount: Int` to `streakCount: Int`.
- Change the rendered string from `"Streak +\(bonusAmount) pt"` to `"\(streakCount) in a row!"`. The 🔥 emoji and the visual treatment stay.
- Update the call site to pass the new parameter name.
- No change to the underlying scoring math, the trigger condition, or the timing of the animation.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `level-gameplay`: ADD a requirement that the streak-bonus animation displays the streak length reached, not the bonus point delta, so the on-screen text cannot be misread as a separate-from-score point award.

## Impact

- **Code**: ~5 lines net across `LevelGameView.swift` (rename, two text changes, one call site).
- **Build**: must remain green.
- **Runtime / player behavior**:
  - Animation cadence and timing unchanged.
  - Animation text now reads "🔥 10 in a row!" / "🔥 20 in a row!" / "🔥 30 in a row!" in Color Only mode, and "🔥 5 in a row!" / "🔥 10 in a row!" / … in Color+Text mode.
  - Score math unchanged — the bonus is still applied to `currentScore` at the same moment as before; only the on-screen wording changes.
- **Tests**: no tests exist today.
- **Migration**: none.
