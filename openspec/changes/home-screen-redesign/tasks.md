## 1. Add CRTabBar component to design system

- [x] 1.1 Create `ColorGame/DesignSystem/Components/CRTabBar.swift` with `CRTabBar` (horizontal item layout, selection binding, safe-area-aware bottom padding) and `CRTabBarItem` model (`id`, `icon: Image`, `selectedTint: Color`)
- [x] 1.2 Each item renders as a `Button { … } label: { Image … }` styled with `.crIcon(tint: …)`, where the tint is the item's `selectedTint` when selected and `Theme.Colors.textMuted` (or similar) when not — implementation uses opacity (1.0 / 0.4) on the brand-tinted icon to convey selection rather than swapping tint, which matches Frame 1 / Frame 10 where both icons keep their brand color
- [x] 1.3 Add a `CRTabBar` showcase section to `DesignSystemPreview.swift` with two items (house + trophy) and a stateful selection toggle

## 2. Add a circular variant of the primary button

- [x] 2.1 Create a sibling `PrimaryCircularButtonStyle` (separate file, not extension of `PrimaryGradientButtonStyle`) with diameter ≥ 88pt (default 180pt), gradient fill, drop shadow, press feedback
- [x] 2.2 Expose via `.buttonStyle(.crPrimaryCircular)` static accessor in `ButtonStyle+Aliases.swift`, plus `.crPrimaryCircular(diameter:)` for sizing
- [x] 2.3 Add the circular variant to `DesignSystemPreview.swift` button section (with play arrow + "Play" label)

## 3. Migrate HomeView to Frame 1

- [x] 3.1 Rewrite `ColorGame/HomeView.swift` body: black background, BEST score top-left (Theme.Colors.textSecondary label + Theme.Colors.pro number), centered `Image("CRLogo")`, tagline with cyan-accented "everything else", circular PLAY button calling `isLevelSystemSelectionPresented = true`, IAP footer hidden when `store.hasRemoveAds`
- [x] 3.2 Remove dead `isRulesViewPresented` state from `HomeView` (was never set to true) — and the corresponding `RulesView` `.fullScreenCover` block
- [x] 3.3 Restyle the IAP entry: compact pill with Remove Ads price + small Restore Purchases link, both using design-system tokens (`Theme.Colors.surfaceElevated` background, `Theme.Colors.textSecondary` for the link)
- [x] 3.4 Drop the v1 four color swatches, the v1 "ColorRush" wordmark Text, and the "Tap squares that DON'T match" tagline
- [x] 3.5 Replace the `LinearGradient` light-theme background with `Theme.Colors.background` (pure black) and replace `.preferredColorScheme(.light)` with `.preferredColorScheme(.dark)`
- [x] 3.6 Verify all behavior preserved: PLAY presents `LevelSystemSelectionView`, `SwitchToLeaderboard` and `DismissToHome` notifications still listened to, IAP purchase / restore wiring unchanged

## 4. Replace MainTabView's TabView with CRTabBar shell

- [x] 4.1 Rewrite `ColorGame/MainTabView.swift`: `ZStack` of HomeView + LeaderboardView with `.opacity` toggling visibility (preserves `@StateObject`s in each tab) plus `.safeAreaInset(edge: .bottom)` for the `CRTabBar`; preserves the `selectedTab: Int` `@State` and the `SwitchToLeaderboard` notification handler that sets `selectedTab = 1`
- [x] 4.2 Pass two `CRTabBarItem`s: house (selected tint = `Theme.Colors.accent` violet) → tag 0, trophy (selected tint = `Theme.Colors.pro` gold) → tag 1
- [x] 4.3 Confirm `LeaderboardView` still renders inside the new shell (its v1 styling is unchanged in this change) — visible via `.opacity(selectedTab == 1 ? 1 : 0)` toggling
- [x] 4.4 Apply `Theme.Colors.background.ignoresSafeArea()` at the root so the chrome blends with the dark theme

## 5. Verification

- [x] 5.1 Build the app with `xcodebuild` and confirm BUILD SUCCEEDED with no new warnings
- [x] 5.2 Run the existing test suite (`ColorGameTests`, `ColorGameUITests`) and confirm zero regression — `xcodebuild test ... iPhone 17` returned **TEST SUCCEEDED**
- [ ] 5.3 Open the Xcode preview for `HomeView` and `DesignSystemPreview` (CRTabBar section); compare against `screens/Frame 1.png` and adjust spacings / tints if needed — **manual review by Tony**
- [ ] 5.4 Launch the app on the simulator: confirm Home renders per Frame 1, PLAY still opens the v1 difficulty picker, switching to Leaderboard shows the v1 list inside the new tab bar shell, IAP/Restore work, and the `SwitchToLeaderboard` notification still drives the tab switch — **manual review by Tony**
- [x] 5.5 Audit `HomeView.swift` for any remaining hex literal, hard-coded font name, or raw point spacing — none remain (only the inline `Image(systemName:).font(.system(size:weight:))` calls for SF Symbol icons, which is the expected pattern for sizing system icons)
