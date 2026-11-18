## 1. Model & logic

- [x] 1.1 Add `GameType.colorMatch` with `displayName`/`description`; fix all exhaustive switches
- [x] 1.2 Make `LeaderboardKey.mistakeTolerance` optional (nil for Color Match), keep existing storage keys unchanged, add `leaderboard.colorMatch`
- [x] 1.3 Create `ColorMatchGame` (state: score, card, time budget) with card generator, answer-balance rule, and `t(n)` acceleration constants
- [x] 1.4 Add unit tests for card generation (balance, no-3-same-in-a-row), time budget monotonicity/floor, game-over on first mistake, timeout handling

## 2. Game UI

- [x] 2.1 Create `ColorMatchGameView`: colored background, centered word, countdown bar, ✓/✗ buttons, score header
- [x] 2.2 Wire haptics/sound feedback, ready beat, pause on scene-phase change
- [x] 2.3 Create the Color Match game-over view (score, best, retry, home); on game over call `LeaderboardStore.addScore` and `GameCenterService.submitScore`

## 3. Integration

- [x] 3.1 Add the mode card (title, description, swatch) in `LevelSystemSelectionView` and route `.colorMatch` to `ColorMatchGameView`, skipping the "How Hard?" step for it
- [x] 3.2 Add Color Match to `LeaderboardView` mode tabs (hide the difficulty filter for it); confirm Home "BEST" includes it
- [x] 3.2b Map Color Match to `tonic.colorrush.leaderboard.colormatch` in `GameCenterService.leaderboardID`
- [x] 3.3 On step 1, add a per-mode rules panel (updates on selection) and rename the primary button "Continue" → "Play" for all modes (Color Match starts the game directly; others go to "How Hard?")
- [x] 3.4 Log `run_started`, `match_answer`, `run_ended` via `LogService`

## 4. Localization

- [x] 4.1 Add `en` + `fr` (state `translated`) entries in `Localizable.xcstrings` for every new string, including color names, per-mode rules texts and the "Play" button; remove the unused "Continue" entry
- [x] 4.2 Grep the diff for hard-coded strings and confirm all go through the catalog

## 5. Verification

- [ ] 5.1 Build and run on simulator in EN and FR; play to game over
- [x] 5.2 Confirm leaderboard entry appears and existing modes still work
- [x] 5.3 (Tony) Create the `tonic.colorrush.leaderboard.colormatch` leaderboard in App Store Connect (integer, high-to-low, en + fr names) and verify a sandbox score submission
