## Why

The Home screen is the entry point of ColorRush and the first surface users see. With the design system foundation now shipped, migrating Home is the natural next step — it's the simplest of the redesigned screens and validates the foundation against a real screen before we tackle denser ones (gameplay, level results). Migrating Home also unlocks the new bottom navigation chrome (custom `CRTabBar`), which is shared with the Leaderboard screen per Frame 10.

## What Changes

- Rebuild `HomeView` to match Frame 1: BEST score text top-left, Color Rush logo image (gradient), tagline "A color is called. Tap everything else.", circular PLAY button with primary gradient, two-icon bottom nav (house + trophy).
- Replace `MainTabView`'s native iOS `TabView` with a custom `CRTabBar` shell so the bottom navigation matches Frame 1 / Frame 10 exactly. `LeaderboardView` continues to render inside the new shell with its current v1 inline styling — its content is **not** migrated in this change.
- Drop the v1 visual elements that don't appear in Frame 1: the four colored swatches above the title and the old "Tap the squares that DON'T match the announced color!" tagline. The new tagline replaces it.
- Keep the IAP entry points — Remove Ads button + Restore Purchases link — at the bottom of Home in a smaller, restyled treatment, still hidden once the entitlement is held. They are not visible in Frame 1 because the Figma design assumes the post-purchase state, but they remain functionally required until purchase.
- Preserve every existing behavior: PLAY still presents the v1 `LevelSystemSelectionView` (the mode/difficulty picker redesign is a separate future change), `SwitchToLeaderboard` and `DismissToHome` notifications still drive tab switching and modal dismissal, the leaderboard tab still resolves to `LeaderboardView`.
- Use only design-system primitives (`Theme.*`, `Font.cr*`, `.crPrimary`, `CRCard` variants if needed) at every call site — no inline hex / font-name / point-value literals.

## Capabilities

### New Capabilities
- `home-screen`: Entry-point screen of the app. Defines what Home displays, what actions it exposes, and how it composes with the navigation chrome.

### Modified Capabilities
- `design-system`: Adds the `CRTabBar` component (custom bottom navigation chrome) as a shared design-system primitive consumed by the app shell. This is an ADDED requirement, not a change to existing tokens / components.

## Impact

- **Modified**: `ColorGame/HomeView.swift` (full rewrite of the body), `ColorGame/MainTabView.swift` (replace `TabView` with `CRTabBar` shell).
- **New**: `ColorGame/DesignSystem/Components/CRTabBar.swift`, `ColorGame/DesignSystem/Components/CRTabBarItem.swift` (or single file).
- **Removed**: dead `isRulesViewPresented` state from `HomeView` (was never set to `true`; the `RulesView` trigger lives in `LevelSystemSelectionView`).
- **No behavior change** for: leaderboard navigation, PLAY entry into the difficulty flow, IAP purchase / restore, notification-driven tab switches.
- **No new dependencies**: pure SwiftUI, consumes existing `RevenueCat`, `LeaderboardStore`, `StoreService` services unchanged.
