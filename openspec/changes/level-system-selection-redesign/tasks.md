## 1. Brand-label + tone extensions

- [x] 1.1 In `ColorGame/LevelSystemSelectionView.swift`, declare `private extension GameType { var brandLabel: String { … } }` mapping `colorOnly` → "PURE" and `colorAndText` → "COLOR+WORD" (kept for parity with `LeaderboardView`; the mode card primary headlines stay friendly "Color ONLY" / "Color and Text" matching Frame 2 wording, declared inline)
- [x] 1.2 Same file, declare `private extension MistakeTolerance { var brandLabel: String { … }; var difficultyTone: Color { … }; var totalLivesCount: Int { … } }` — `brandLabel` returns ROOKIE / PRO / INSANE, `difficultyTone` returns `Theme.Colors.success` / `.pro` / `.danger`, `totalLivesCount` returns 5 / 3 / 1

## 2. Screen scaffold + step transitions

- [x] 2.1 Replace the v1 `NavigationView { ZStack { LinearGradient … } }` shell with `ZStack { Theme.Colors.background.ignoresSafeArea(); … }` plus `.preferredColorScheme(.dark)`
- [x] 2.2 Render the step indicator using `CRSectionHeader(title:, step:, onBack:)` with `step` = "Step 1/2" on Step 1 and "Step 2/2" on Step 2; `onBack` triggers `handleBack()` which dispatches step 2 → step 1 / step 1 → dismiss
- [x] 2.3 Switch the step content with `if currentStep == .gameType { gameTypeSelectionView } else { mistakeToleranceSelectionView }` wrapped in `withAnimation(.easeInOut(duration: 0.25))` for a smooth transition

## 3. Step 1 — Pick a Mode

- [x] 3.1 Build `gameTypeSelectionView` as a `VStack` of two mode cards (Color ONLY, Color and Text), vertically stacked with `Theme.Spacing.lg`
- [x] 3.2 Inside each card: an `HStack` with a left-aligned `ModeSwatchGrid` and a right-aligned text block with the title (`.crHeadline`) and the description (`.crBody`, `Theme.Colors.textSecondary`)
- [x] 3.3 Implement private `ModeSwatchGrid(showsLabels: Bool)`: 2×2 LazyVGrid of `Theme.Colors.Tile.red` / `.blue` / `.green` / `.yellow` rounded squares; when `showsLabels == true`, each square contains a contrasting word label (BLUE on red, RED on blue, GREEN on green, RED on yellow — illustrating the gameplay mismatch)
- [x] 3.4 Selected mode card uses 2pt `strokeBorder` in `Theme.Colors.accentSecondary`; non-selected uses 1pt `Theme.Colors.border`
- [x] 3.5 Add the conditional `CRChip(title: "Recommended to start", tone: .accent)` overlay on the Color ONLY card top-right, gated by `shouldRecommendColorOnly`
- [x] 3.6 `shouldRecommendColorOnly`: `MistakeTolerance.allCases.allSatisfy { LeaderboardStore.shared.getScores(gameType: .colorAndText, mistakeTolerance: $0).isEmpty }`. The leaderboard store is observed via `@StateObject` so the chip lifecycle is reactive.
- [x] 3.7 Add the "CONTINUE" button at the bottom: `Button("Continue") { … }.buttonStyle(.crPrimary)`, disabled when no mode is selected, opacity halved when disabled
- [x] 3.8 On CONTINUE tap, `withAnimation { currentStep = .mistakeTolerance }` and ensure `selectedMistakeTolerance ?? .easy` is set on `levelRun.mistakeTolerance`

## 4. Step 2 — How Hard?

- [x] 4.1 Build `mistakeToleranceSelectionView` as a `VStack` of three difficulty cards (ROOKIE / PRO / INSANE), vertically stacked with `Theme.Spacing.lg`
- [x] 4.2 Inside each card: a left-edge 4pt accent strip (in the difficulty's `difficultyTone`), the brand label (`.crHeadline`) + description (`.crBody`, `Theme.Colors.textSecondary`) in a `VStack`, and a right-aligned `HeartsRow(count:)` showing 5 / 3 / 1 hearts
- [x] 4.3 Implement private `HeartsRow(count: Int)`: `HStack` of `count` `Image(systemName: "heart.fill")` tinted `Theme.Colors.danger`, 16pt bold
- [x] 4.4 Selected difficulty card uses 2pt `strokeBorder` in its `difficultyTone`; non-selected uses 1pt `Theme.Colors.border`
- [x] 4.5 Add the "LET'S GO" button at the bottom: `Button("Let's go") { startLevelRun() }.buttonStyle(.crPrimary)`, disabled when `selectedMistakeTolerance == nil`

## 5. Cleanup of v1 elements

- [x] 5.1 Removed the v1 progress dots, chevron-row card style, emoji rocket "Start now!" button, "How to play?" link, `isRulesViewPresented` state, and `RulesView` `fullScreenCover`
- [x] 5.2 `RulesView.swift` is NOT modified or deleted (verified via diff)
- [x] 5.3 Removed unused imports during the rewrite (no leftover `import GameKit`, etc.)

## 6. Verification

- [x] 6.1 Build the app with `xcodebuild` and confirm BUILD SUCCEEDED with no new warnings
- [x] 6.2 Run the unit test suite (`-only-testing:ColorGameTests -parallel-testing-enabled NO`) — **TEST SUCCEEDED**
- [ ] 6.3 Open `LevelSystemSelectionView` in Xcode preview; visually compare against `screens/Frame 2.png` (Step 1) and `screens/Frame 3.png` (Step 2); verify the recommended-to-start chip toggles when scores are present — **manual review by Tony**
- [ ] 6.4 Launch on simulator: tap PLAY from Home, verify Step 1 layout, tap each mode (selection state, no auto-advance), tap CONTINUE, verify Step 2 layout with `.easy` pre-selected, tap each difficulty (border colour switches), back to Step 1, back dismisses, LET'S GO opens game — **manual review by Tony**
- [x] 6.5 Audit `LevelSystemSelectionView.swift`: no hex literal, no hard-coded font name, no raw point spacing, no emoji as visual layout icon — clean, every visual value sourced from `Theme.*` / `Font.cr*`
- [x] 6.6 Audit the diff: `LevelSystemModels.swift`, `LevelGameView.swift`, `RulesView.swift`, `HomeView.swift`, and `MainTabView.swift` are NOT modified
