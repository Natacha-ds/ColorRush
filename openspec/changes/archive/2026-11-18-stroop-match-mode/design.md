## Context

Existing modes (`GameType.colorOnly`, `.colorAndText`) run through `LevelGameView` / `LevelRun`: a 2641-line, level-based, tile-tapping session. Color Match has a different loop (one card at a time, binary answer, continuous timer) and does not use levels, tiles or the called-color voice. Scores live in `LeaderboardStore`, keyed by (`GameType`, `MistakeTolerance`); the store, selection view and leaderboard view all iterate `GameType.allCases`.

## Goals / Non-Goals

**Goals:**
- Ship the mode with the same entry flow (Play → Pick a Mode → How Hard? → game) and the same leaderboard/game-over conventions.
- Keep game logic testable and separate from the view.
- Accelerating pace that is fair: fast, never impossible.

**Non-Goals:**
- No refactor of `LevelGameView`/`LevelRun`.
- No difficulty levels or lives for this mode; no new voice audio; no ads placement changes.

## Decisions

1. **New `GameType.colorMatch`, own view.** Reusing `GameType` gives leaderboard storage and the mode-selection list for free. The selection view routes `.colorMatch` to `ColorMatchGameView` instead of `LevelGameView`, and skips the "How Hard?" step for it (the step-1 CTA reads "Play" for every mode: it goes to step 2 for the existing modes and starts the game for Color Match).
7. **Rules on step 1.** A rules panel below the mode cards shows the selected mode's rules (title, 2–3 short lines), animated on selection change. Rules text is keyed per mode so existing modes get theirs too (reusing their current descriptions). `RulesView` is not referenced anywhere in the app and is left untouched. Alternative (separate Home button + separate store) rejected: duplicates leaderboard UI and fragments the "Play" entry point.
2. **Logic in `ColorMatchGame` (ObservableObject, no SwiftUI types).** Holds score, current card, per-card time budget. Injectable `RandomNumberGenerator` and a clock-agnostic `tick(dt)` so it is unit-testable.
3. **Card generation.** Palette = 8 softened colors (red, orange, yellow, green, blue, purple, pink, gray) defined in `MatchColor`, chosen to be comfortable as a full-screen background rather than the saturated system primaries. Word = random color name; background = same color with ~50 % probability, otherwise a different one. Avoid more than 3 identical answers (✓ or ✗) in a row so the player can't coast on a pattern. The word is drawn in neutral white on the colored background so the only signal is name vs. background (no ink-color Stroop confound).
4. **Timer acceleration.** Time per card: `t(n) = max(0.7, 3.0 × 0.96^n)` seconds (n = correct answers so far). A bar drains over `t(n)` on each card; reaching 0 is a wrong answer. Constants live in one place for easy tuning.
5. **Single-bucket leaderboard, one mistake ends the run.** Score = number of cards passed. First wrong answer or timeout → game over → `LeaderboardStore.addScore` + `GameCenterService.submitScore`. `LeaderboardKey.mistakeTolerance` becomes `MistakeTolerance?` (nil for `.colorMatch`), storage key `leaderboard.colorMatch`; existing keys are unchanged. Alternative (fake a fixed tolerance such as `.hard`) rejected: it would leak a meaningless "Hard" label into the UI and Game Center IDs.
6. **Feedback & input.** Two large buttons (✓ green, ✗ red) in the existing design system; haptics via `HapticsService`, clicks via `SoundService`. The first card starts after a short 3-2-1 / "Ready" beat. Pause when the app backgrounds (scene phase) so the timer can't drain unseen.
8. **Localization.** All new strings (mode name/description, buttons' accessibility labels, color names as shown, game-over copy, rules text) are added to `Localizable.xcstrings` with `en` + `fr`. Color names displayed are localized (e.g. ROUGE/BLEU/VERT/JAUNE) by key lookup, not by string concatenation.

## Risks / Trade-offs

- [Added `GameType` case breaks exhaustive switches] → compiler lists every site; fix all (`displayName`, `description`, selection `modeTitle/modeDescription`, leaderboard tabs).
- [Existing UserDefaults leaderboard keys] → new key is additive (`leaderboard.colorMatch`), no migration needed; the v2 reset flag is untouched.
- [Optional tolerance touches every `LeaderboardKey` call site and the Game Center ID mapping] → compiler-guided; keep existing storage keys byte-identical.
- [Game Center leaderboard missing in App Store Connect → `loadLeaderboards` returns empty, rank not shown] → code already tolerates this (`guard let leaderboard`); create the leaderboard before release.
- [Timer feels unfair on slow devices] → driven by `TimelineView`/`Date` deltas, not frame count; floor of 0.7 s.
- [Difficulty tuning guesses] → constants isolated; adjust after playtests.
- [One mistake ends the run, so a mis-tap is costly] → large buttons, generous first-card time (3.0 s), accepted as the intended One Brain-style tension.

## Migration Plan

Additive only. Ship in the next version; rollback = revert the commit (no persisted data format changes).
