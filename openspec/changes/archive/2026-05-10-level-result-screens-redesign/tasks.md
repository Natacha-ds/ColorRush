## 1. Shared layout helper

- [x] 1.1 Declare `private struct LevelResultBody<PrimaryButton: View>` at module scope in `LevelGameView.swift` just before `LevelCompleteView`. Parameters: total score, remaining lives + total lives, icon, icon tint, headline, subtitle, divider color, level score, required score, hits / misses / streak point values, primary button (generic), `onBackToHome` closure
- [x] 1.2 Body lays out the full result structure: black `ZStack` background, top row (TOTAL SCORE label/number on left + `CRHeartsPill` on right), centered icon + headline + subtitle, tone-coloured divider, YOUR SCORE card, stats trio HStack, primary CTA, HOME text-link
- [x] 1.3 Uses `Theme.Colors.background`, `Theme.Spacing.*`, `.crLabel` / `.crDisplay` / `.crCaption` / `.crBody` / `.crScoreHero`, `.preferredColorScheme(.dark)` at the root

## 2. Top row + hero section

- [x] 2.1 Top `HStack` with left-aligned VStack (TOTAL SCORE label + number) + Spacer + `CRHeartsPill`
- [x] 2.2 Centered VStack: SF Symbol icon (size 64pt bold) tinted via `.foregroundStyle(iconTint)`, `.crDisplay` headline, `.crLabel` subtitle in textSecondary
- [x] 2.3 Tone-coloured divider via `Rectangle().fill(dividerColor).frame(height: 2).padding(.horizontal, Theme.Spacing.xxxl)`

## 3. YOUR SCORE card

- [x] 3.1 `VStack` wrapped in `RoundedRectangle.fill(Theme.Colors.surface)` rounded `Theme.Radius.lg`
- [x] 3.2 Inside: "Your Score" `.crLabel` uppercase textSecondary, level score `.crScoreHero` textPrimary, "Of NNN" `.crBody` textSecondary

## 4. Stats trio

- [x] 4.1 `HStack(spacing: Theme.Spacing.md)` of three `CRStatBadge`s with `frame(maxWidth: .infinity)` so they share the row evenly
- [x] 4.2 HITS: `value = hitsPoints > 0 ? "+\(hitsPoints)" : "0"`, tone `.success`
- [x] 4.3 MISSES: `value = missesPoints == 0 ? "0" : "\(missesPoints)"`, tone `.warning` (already negative)
- [x] 4.4 STREAK: `value = streakBonus > 0 ? "+\(streakBonus)" : "0"`, tone `.info`

## 5. Action area (primary CTA + HOME link)

- [x] 5.1 Generic `primaryButton` parameter — each screen passes its own configured Button (`.crPrimary` style)
- [x] 5.2 HOME link: `Button(action: onBackToHome) { Text("Home").font(.crButtonLabel).textCase(.uppercase) }.buttonStyle(.plain)`

## 6. Wire LevelCompleteView (Frame 7)

- [x] 6.1 Rewrite `LevelCompleteView.body` to delegate to `LevelResultBody` with success-tone content: `iconTint = Theme.Colors.success`, `Image(systemName: "bolt.fill")`, headline "Amazing", subtitle "Level NN - Succeed", green divider, primary button = `Button(levelRun.isCompleted ? "Finish Run" : "Next Level", action: onNextLevel).buttonStyle(.crPrimary)`. All data wired from `levelRun` properties (`globalScore + levelPositivePoints` total, `getCurrentLevelScore()` level score, `levelBasePoints` for hits, `levelWrongTaps * -10` for misses, `levelStreakBonuses` for streak)
- [x] 6.2 Dropped v1 helpers no longer referenced (`correctAnswersDisplayValue`, `correctAnswersPoints`, `mistakesPenalty`, `timeoutsPenalty`, `shouldShowBonus`, `shouldShowMissed`, `remainingLives`); kept `finalLevelScore` and `totalScoreWithCurrentLevel` since they're still useful

## 7. Wire LevelFailedView (Frame 6)

- [x] 7.1 Rewrite `LevelFailedView.body` similarly with failed-tone: `Image(systemName: "skull")`, `iconTint = Theme.Colors.warning`, headline "Too slow", subtitle "Level NN - Failed", orange divider, primary button = TRY AGAIN with `Image(systemName: "arrow.clockwise")` 18pt bold prefix
- [x] 7.2 Dropped the v1 helpers no longer referenced (same set as LevelCompleteView)

## 8. Cleanup

- [x] 8.1 No `Color(hex: "...")` literals, no `Image("Heart")` / `Image("Bomb")` / `Image("Crown")` / `Image("Cup")` / `Image("Fail")` / `Image("Stars")` / `Image("Timing")` references, no system gradient backgrounds remain in the rewritten bodies
- [x] 8.2 `Theme.Spacing.*` / `Theme.Radius.*` / `Font.cr*` are used everywhere in the new code
- [x] 8.3 v1 conditional flags `shouldShowBonus` / `shouldShowMissed` removed — the new design always shows all three stats
- [x] 8.4 Removed the v1 `StatBlock` helper struct (no longer used; HITS / MISSES / STREAK now use the shared `CRStatBadge` component from the design system)

## 9. Verification

- [x] 9.1 Build the app with `xcodebuild` and confirm BUILD SUCCEEDED with no new warnings
- [x] 9.2 Run the unit test suite (`-only-testing:ColorGameTests -parallel-testing-enabled NO`) — **TEST SUCCEEDED**
- [ ] 9.3 Open the views in Xcode preview; visually compare against `screens/Frame 6.png` (failed) and `screens/Frame 7.png` (success) — **manual review by Tony**
- [ ] 9.4 Launch on simulator: complete a level (success path) → verify Frame 7 with HITS/MISSES/STREAK matching the run; tap NEXT LEVEL → next level intro shows. Fail a level (insufficient score, lives remain) → verify Frame 6 with skull, orange tone, "TRY AGAIN" CTA; tap TRY AGAIN → same level intro shows. Tap HOME from either screen → Home returns — **manual review by Tony**
- [x] 9.5 Audited the rewritten bodies of `LevelCompleteView` and `LevelFailedView`: no hex literal, no hard-coded font name, no raw point spacing, no emoji as visual icon, no `Image("…")` legacy assets — confirmed clean
- [x] 9.6 Audited the diff: `LevelSystemModels.swift`, `Tile.swift`, `RulesView.swift`, `FinalWinView`, the run-ending game-over view, and the active gameplay portion of `LevelGameView` are NOT modified; only the inline `LevelCompleteView` + `LevelFailedView` bodies + the new private `LevelResultBody` helper are touched (and the now-unused `StatBlock` struct deleted)
