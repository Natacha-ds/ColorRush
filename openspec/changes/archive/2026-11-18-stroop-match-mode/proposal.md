## Why

ColorRush has two game modes, and both are "tap the tile that is not the called color". A third, structurally different mode — a fast true/false color-matching reflex game — adds variety for returning players and a fresh hook for new ones, with a very short learning curve (one glance, one tap).

## What Changes

- Add a new game mode, **Color Match**: a color name is written in the center of the screen over a colored background. The background is either the written color or a different one. The player taps ✓ (same) or ✗ (different) before the timer runs out.
- A countdown timer bar drains on every card; the time allowed per card shrinks as the streak grows, so the pace keeps accelerating.
- A correct answer scores a point (the score is the number of cards passed) and shows the next card. The first wrong answer or timeout ends the run. There is **no difficulty level** for this mode: the accelerating timer is the only difficulty ramp.
- Expose the mode in the existing "Pick a Mode" step of `LevelSystemSelectionView`; for this mode the "How Hard?" step is skipped and the step-1 "Play" button starts the game directly.
- Step 1 shows the **rules of the selected mode** (a short rules panel under the mode cards that updates on selection), and its primary button is renamed from "Continue" to "Play" for every mode. The existing modes keep their "How Hard?" step after "Play". Scores go in the existing local leaderboard (new `GameType` case, single bucket).
- Submit the score to a new Game Center leaderboard `tonic.colorrush.leaderboard.colormatch` (to be created in App Store Connect) and show it in the leaderboard screen.
- Add a Game Over screen for the mode (score, best, retry, home), consistent with the existing one.
- Add `en` + `fr` entries to `Localizable.xcstrings` for every new string (including per-mode rules text); remove the now-unused "Continue" entry.
- Log analytics events through `LogService` (`run_started` with the new game type, `match_answer`, `run_ended`).

## Capabilities

### New Capabilities
- `color-match-gameplay`: rules, timer acceleration, scoring and game-over flow of the Color Match mode.

### Modified Capabilities
- `level-system-selection`: the "Pick a Mode" step lists a third mode, shows the selected mode's rules, renames the primary button to "Play" and routes Color Match to its game view.
- `leaderboard-screen`: the leaderboard includes the new game type bucket(s).
- `i18n`: new strings must be available in `en` and `fr`.

## Impact

- Code:
  - `ColorGame/LevelSystemModels.swift` — new `GameType` case (+ display name/description).
  - `ColorGame/LevelSystemSelectionView.swift` — mode card, routing to the new view.
  - New `ColorGame/ColorMatchGameView.swift` (+ small view model / game state) and a game-over view.
  - `ColorGame/LeaderboardStore.swift`, `LeaderboardView.swift` — `LeaderboardKey.mistakeTolerance` becomes optional (nil for Color Match); the difficulty filter is hidden for this mode.
  - `ColorGame/GameCenterService.swift` — map the Color Match bucket to its leaderboard ID.
  - `ColorGame/Localizable.xcstrings` — new EN + FR strings.
- Audio: color names are shown as text only; existing voice mp3s are not required (no new `.mp3`).
- Manual step: create the Game Center leaderboard `tonic.colorrush.leaderboard.colormatch` (Classic, integer score, high-to-low) in App Store Connect, with `en` + `fr` display names.
- No changes to ads, IAP, or Game Center authentication.
