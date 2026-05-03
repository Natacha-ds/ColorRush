## Why

Five small audit items remain and each is one-to-three lines of defensive hardening across `HapticsService`, `LeaderboardStore`, and `LevelGameView`. Bundling them into a single change keeps the OpenSpec workflow proportionate to the size of the work, and gives one cohesive "robustness pass" before adding ads/IAP plumbing on top.

## What Changes

- **BUG-013**: in `HapticsService`, hold shared `UIImpactFeedbackGenerator` instances at class scope and reuse them, instead of instantiating a fresh generator on every haptic call.
- **BUG-015**: in `LeaderboardStore.loadScores(forKey:)`, replace the silent `try? JSONDecoder().decode(...)` with a `do { try } catch { print(...) }` block so corrupted persistence surfaces in logs instead of silently wiping the leaderboard.
- **BUG-019**: in `LevelGameView.startNewLevel()`, prepend a `guard isLevelFailed || isLevelComplete else { return }` re-entrance guard so a rapid double-tap on "Try Again" cannot trigger two consecutive level resets.
- **BUG-020**: in `LevelGameView.handleTimeUp()`, replace the bare `return` on a missing `currentLevelConfig` with a defensive `isLevelFailed = true; failedReason = .insufficientScore; return` so the view never silently freezes if the config is somehow unavailable.
- **BUG-016**: closed in this proposal **without a code change**. The audit hypothesised a 0.2–0.5 s freeze from `buildValidGrid()`, but reading the code shows `maxAttempts = 20` (microseconds per iteration) and a deterministic fallback path that always returns a valid grid. No real freeze risk; no actionable fix needed.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `level-gameplay`: ADD a single umbrella requirement for defensive guards against pathological inputs and edge cases, with one scenario per fix.

## Impact

- **Code**: ~15 lines net across three files — `HapticsService.swift`, `LeaderboardStore.swift`, `LevelGameView.swift`.
- **Build**: must remain green.
- **Runtime / player behavior**:
  - Haptics now fire reliably on rapid taps (no dropped feedback from generator init overhead).
  - A corrupted leaderboard JSON now logs and resets gracefully instead of silently disappearing.
  - Rapid "Try Again" tapping cannot trigger double resets.
  - The handleTimeUp edge case (nil config) now fails the level cleanly instead of freezing the view.
- **Persistence**: no schema change. Existing leaderboard data is unaffected; only the read path becomes louder on corruption.
- **Tests**: no tests exist today.
- **Migration**: none.
