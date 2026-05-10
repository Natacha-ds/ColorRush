## 1. Background and chrome

- [x] 1.1 Replace the v1 light `LinearGradient` background (`F5F0FF` → white) with `ZStack { Theme.Colors.background.ignoresSafeArea(); Theme.Gradient.gameOverWash.ignoresSafeArea() }` so the radial dark-red wash sits over the pure-black bg
- [x] 1.2 Apply `.preferredColorScheme(.dark)` at the root of `LevelGameOverView.body`

## 2. Top hearts pill

- [x] 2.1 Render `CRHeartsPill(remaining: 0, total: levelRun.mistakeTolerance.totalLives)` aligned top-right (the player has run out, so all hearts dimmed)
- [x] 2.2 Drop the v1 custom gradient capsule with `Image("Heart")` + count

## 3. GAME OVER headline + divider

- [x] 3.1 Big `Text("Game Over").font(.crDisplay).textCase(.uppercase).foregroundStyle(Theme.Colors.danger)`
- [x] 3.2 Below the headline, `Text("No lives left").font(.crLabel).textCase(.uppercase).foregroundStyle(Theme.Colors.textSecondary)`
- [x] 3.3 Below the subtitle, a horizontal divider via `Rectangle().fill(Theme.Colors.danger).frame(height: 2).padding(.horizontal, Theme.Spacing.xxxl)`

## 4. YOUR TOTAL SCORE card

- [x] 4.1 Render a `VStack(spacing: Theme.Spacing.xs)` with "Your Total Score" `.crLabel` uppercase `Theme.Colors.textSecondary` + the score number `\(totalScoreWithCurrentLevel)` in `.crScoreHero` `Theme.Colors.textPrimary`
- [x] 4.2 Background `RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.Colors.surface)` with vertical padding `Theme.Spacing.lg` and horizontal padding `Theme.Spacing.xl`
- [x] 4.3 `totalScoreWithCurrentLevel = levelRun.globalScore + levelRun.levelPositivePoints` (matches v1)

## 5. DON'T STOP NOW prompt + +1 LIFE rewarded revive card

- [x] 5.1 `Text("Don't stop now").font(.crHeadline).textCase(.uppercase).foregroundStyle(Theme.Colors.textPrimary)` + `Text("Watch an ad, get back in").font(.crBody).foregroundStyle(Theme.Colors.textSecondary)`
- [x] 5.2 Build a private `rewardedReviveCard` view: `heart.fill` SF Symbol (cyan) on the left, `VStack` with reward label "+1 Life" (.crLabel uppercase) + sublabel ("Watch 1 Ad" or "Free" if Remove Ads holder) in the middle, "Watch" pill on the right styled with cyan tint
- [x] 5.3 Render the +1 LIFE card only when `!levelRun.hasUsedRewardedRevive`. Disabled visually when `!isContinueButtonEnabled`. `onTap` calls the existing `handleContinueTap` (which does `markReviveAttempted` + `showRewardedAdIfReady`)
- [x] 5.4 **+2 LIVES card NOT rendered** in this change (per Tony's decision). The +2 ads chain capability is deferred to a future change

## 6. Primary CTA + HOME link

- [x] 6.1 Render the START OVER button: `Button(action: onBackToHome) { HStack { Image("CRRetry") template + "Start Over" } }.buttonStyle(.crDanger)`
- [x] 6.2 Below the CTA, a centered `Button(action: onBackToHome) { Text("Back to Home").font(.crButtonLabel).textCase(.uppercase).foregroundStyle(Theme.Colors.textSecondary) }.buttonStyle(.plain)`

## 7. Cleanup

- [x] 7.1 Removed v1 visual elements: `Image("Game-Over")` + `Image("Heart")`, the orange-pink revive button gradient + capsule + shadow, the v1 "Start a new game" 3-color gradient button, the gradient bg
- [x] 7.2 Dropped the unused `lossReason` and `remainingLives` private helpers (no longer referenced)
- [x] 7.3 Confirmed `handleContinueTap` (existing private helper that wraps `markReviveAttempted` + `showRewardedAdIfReady`) is preserved and reused

## 8. Verification

- [x] 8.1 Build the app with `xcodebuild` and confirm BUILD SUCCEEDED with no new warnings
- [x] 8.2 Run the unit test suite (`-only-testing:ColorGameTests -parallel-testing-enabled NO`) — **TEST SUCCEEDED**
- [ ] 8.3 Open `LevelGameOverView` in Xcode preview (mock a `LevelRun` with `hasUsedRewardedRevive = false` then `= true`); compare against `screens/Frame 8.png` — verify wash background, hearts pill, GAME OVER + divider, score card, +1 LIFE card, START OVER + HOME link — **manual review by Tony**
- [ ] 8.4 Launch on simulator: play INSANE difficulty (1 life), tap a wrong tile to lose the run → verify Game Over screen renders. Tap +1 LIFE card → verify rewarded ad presents and on completion the run resumes. Tap START OVER → verify exit to Home. Tap BACK TO HOME → verify same exit — **manual review by Tony**
- [x] 8.5 Audited the rewritten `LevelGameOverView.body`: no hex literal, no hard-coded font name, no raw point spacing, no `Image("Heart"/"Game-Over")` reference, no emoji as visual icon
- [x] 8.6 Audited the diff: `LevelSystemModels.swift`, `Tile.swift`, `AdsService.swift`, `StoreService.swift`, and other gameplay-state files are NOT modified — only the inline `LevelGameOverView` struct body changes
