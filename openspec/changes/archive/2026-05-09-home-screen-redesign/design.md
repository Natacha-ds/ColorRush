## Context

The v1 Home view is implemented inline in `HomeView.swift` with light-theme styling, system fonts, and emoji icons. The screen also lives inside `MainTabView` which uses iOS's native `TabView` for the Home / Leaderboard tabs. The new design (Frame 1) is dark-themed, uses Montserrat italic typography, exposes a smaller IAP footer, and replaces the system tab bar with a fully bespoke 2-icon bottom navigation that is visually shared with the Leaderboard screen (Frame 10).

The design system foundation that landed in `2026-05-09-design-system-foundation` provides every primitive needed (`Theme`, `Font.cr*`, gradient button styles, `CRCard`) except the bottom navigation chrome — which we add in this change.

Constraints:
- Pure SwiftUI, no third-party dependency.
- Must preserve every existing Home behavior: PLAY entry into the difficulty flow, tab switch to Leaderboard, IAP purchase / restore, notification listeners.
- Must compose with the v1 `LeaderboardView` (not migrated yet) — the new tab bar shell wraps a v1-styled inner view without breaking it.
- Free-tier Figma — no Dev Mode MCP. Layout values (margins, sizes) are eyeballed from the PNG at Frame 1 and tuned in preview.

## Goals / Non-Goals

**Goals:**
- Migrate `HomeView` to Frame 1's exact layout consuming only design-system primitives.
- Introduce `CRTabBar` as a shared design-system component so both Home and Leaderboard can use it now and any future bottom-nav consumer gets it for free.
- Replace `MainTabView`'s `TabView` with a `CRTabBar`-driven shell; preserve the existing two destinations (Home / Leaderboard) and the `SwitchToLeaderboard` notification handler.
- Keep IAP/Restore visible on Home (smaller footer treatment) until purchased.
- Drop dead state (`isRulesViewPresented` in `HomeView`) and v1 visual elements absent from Frame 1 (color swatches, old tagline).

**Non-Goals:**
- Migrate `LeaderboardView` content. It stays v1 styled inside the new tab bar shell. Migration is a follow-up change.
- Migrate `LevelSystemSelectionView` (the difficulty/mode picker triggered by PLAY). Frames 2-3 will drive that change.
- Implement the gameplay tap-particle background — that's tied to Frame 5.
- Add a Settings screen. Frame 9 was confirmed not to exist (Figma numbering jumps from 8 to 10).
- Vectorize the logo. We use the PNG asset (`CRLogo`) in `Assets.xcassets`.

## Decisions

### Decision 1: Custom `CRTabBar` over native `TabView`

We replace SwiftUI's `TabView` with a custom bottom bar component. Native `TabView` styling APIs (`.tabViewStyle`, `UITabBarAppearance` bridging) cannot reproduce Frame 1's look (custom icon sizes, custom selection indicator color per item, no separator line) without significant ceremony. A custom bar is ~50 lines of SwiftUI and gives full control.

**Why over native:** Frame 1 / Frame 10 use a chrome-less, two-icon centered layout with **per-icon brand color** for selected state (purple house, gold trophy). Native `TabView` enforces a single accent color for selection and adds a translucent material strip we don't want.

**Alternative considered:** `TabView` with `.tabViewStyle(.page)` and a custom overlay. Rejected — fights the framework, fragile across iOS versions.

### Decision 2: `CRTabBar` lives in the design-system capability

Since the bar is reused by Leaderboard and likely any future bottom-nav surface, it's an app-shell primitive, not a Home-specific component. We add it as a new requirement under the existing `design-system` capability rather than under `home-screen`.

**Alternative considered:** Put it in `home-screen` initially and refactor later. Rejected — moves the file twice for no benefit; the component's API surface is stable.

### Decision 3: `MainTabView` becomes a thin shell wiring `CRTabBar` to a content `Group`

```
MainTabView
  ZStack
    [content view based on selectedTab]
    VStack { Spacer; CRTabBar(items: ..., selection: $selectedTab) }
```

The content view is rebuilt on selection change. Each destination keeps its existing identity / state via `@StateObject` injection patterns — no behavior change.

**Why over `TabView`:** lets us anchor the tab bar at the bottom safe area without competing with `TabView`'s built-in chrome.

### Decision 4: IAP/Restore stay on Home, restyled

Frame 1 doesn't show them, but they're a hard product requirement until purchased (single-payment IAP that hides itself post-purchase). We render them as a compact pill + underlined link below the PLAY button area, using `Theme.Colors.surfaceElevated` for the pill background and `Theme.Colors.textSecondary` for the restore link. They stay hidden when `store.hasRemoveAds` is true.

**Why this placement:** keeps PLAY as the visual focus. The IAP entry is reachable but visually deprioritized — matching the design's intent (Frame 1 implicitly shows the post-purchase state).

### Decision 5: Drop dead `isRulesViewPresented` state from `HomeView`

The state exists in v1 but is never set to `true` from `HomeView` (the `RulesView` trigger lives only in `LevelSystemSelectionView`). We remove it during the migration to keep the new file clean. Trivial cleanup.

### Decision 6: `BEST` score top-left as plain text, not capsule

Frame 1 shows the best score as small uppercase "BEST" label + bold italic number, top-left, no surrounding capsule or shadow. We replicate exactly — `Theme.Colors.textSecondary` for the label, `Font.crTitle` (or a tuned variant) for the number colored `Theme.Colors.pro` (gold) to match the Figma rendering.

## Risks / Trade-offs

- **[Risk]** Replacing native `TabView` removes implicit features — no native gesture for tab swipe, no automatic safe-area handling for the bar → **Mitigation:** the CRTabBar explicitly pads against the bottom safe area; tab swipe was never used by ColorRush.
- **[Risk]** The IAP footer treatment may diverge stylistically from Frame 1 (since Tony chose to keep it visible despite its absence in the Figma) → **Mitigation:** keep it visually muted; iterate after the first preview screenshot.
- **[Risk]** `LeaderboardView` v1 inside new tab bar shell will look stylistically split (dark chrome + light content) until migrated → accepted: temporary inconsistency; the next change after Home migrates Leaderboard.
- **[Trade-off]** Going custom on the tab bar means we own its accessibility (VoiceOver labels, hit areas) → mitigated by matching Apple's tab bar patterns (≥44pt tap targets, descriptive labels).

## Migration Plan

1. Add `CRTabBar` component to `ColorGame/DesignSystem/Components/`.
2. Rewrite `HomeView.swift` body using design-system primitives; preserve all `@StateObject`s and notification listeners.
3. Rewrite `MainTabView.swift` to use a `ZStack` + `CRTabBar` instead of native `TabView`.
4. Verify in `DesignSystemPreview` (add a `CRTabBar` showcase section) and in the simulator on Home + Leaderboard tabs.
5. Run existing test suite; UI launch tests should still pass since the screen identifiers are preserved.

Rollback: revert the three modified files; the design-system foundation stays in place untouched.

## Open Questions

- Exact "BEST" number color in Frame 1 — gold (`pro`) is my read from the screenshot; confirm in preview against the PNG.
- Do we want a subtle press feedback on the tab bar icons (scale + opacity) or just instant selection? Default to subtle press scale to match the rest of the design system, revisit if it feels off.
