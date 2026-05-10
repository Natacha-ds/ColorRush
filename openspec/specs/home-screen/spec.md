# home-screen Specification

## Purpose
TBD - created by archiving change home-screen-redesign. Update Purpose after archive.
## Requirements
### Requirement: Home screen layout

The Home screen SHALL render the following elements, vertically stacked on a black background, matching Frame 1: a "BEST" label and the user's overall best score in the top-left corner; a settings gear icon button in the top-right corner aligned with the BEST block; the Color Rush logo image centered; a tagline reading "A color is called. Tap anything else." with the second sentence styled in the brand cyan accent and the whole block center-aligned beneath the logo; a circular gradient PLAY button centered as the primary call-to-action; a compact IAP footer (Remove Ads pill only — no Restore link) below the PLAY button, hidden when the entitlement is held; a custom bottom navigation bar with two icons (house, trophy).

#### Scenario: Best score visible
- **WHEN** the Home screen renders and the user has at least one recorded score
- **THEN** the top-left of the screen shows "BEST" in a small uppercase label and the score number underneath in a bold italic display style

#### Scenario: No best score yet
- **WHEN** the user has never completed a level
- **THEN** the top-left shows "BEST" with a placeholder dash ("—") in place of the score

#### Scenario: PLAY enters the difficulty flow
- **WHEN** the user taps the PLAY button
- **THEN** the existing level/difficulty selection flow is presented as a full-screen cover (current behavior preserved)

#### Scenario: Tagline content (EN)
- **WHEN** the Home screen renders on an EN-locale device
- **THEN** the tagline reads "A color is called. / Tap anything else." with the phrase "anything else." rendered in the brand cyan accent color, and both lines are horizontally centered beneath the logo

#### Scenario: Tagline content (FR)
- **WHEN** the Home screen renders on a FR-locale device
- **THEN** the tagline reads "Une seule règle : / ne touche pas la couleur annoncée." with the phrase "la couleur annoncée." rendered in the brand cyan accent color, and both lines are horizontally centered beneath the logo. The FR copy phrases the rule negatively (don't tap [the called color]) while the EN copy phrases it positively (tap [anything else]); both are correct framings of the same gameplay rule.

#### Scenario: Settings gear icon visible
- **WHEN** the Home screen renders
- **THEN** a gear icon button is present in the top-right corner, vertically aligned with the BEST block on the left

### Requirement: IAP entry on Home

The Home screen SHALL expose the Remove Ads single-payment purchase below the PLAY button, with a compact / footer-style treatment, only when the user does not already hold the entitlement. The Restore Purchases action SHALL NOT appear in this footer; it lives exclusively inside the settings sheet (see "Settings sheet" requirement).

#### Scenario: User does not own Remove Ads
- **WHEN** the Home screen renders and `StoreService.hasRemoveAds` is false
- **THEN** a Remove Ads pill (showing the localized price) is visible below the PLAY button. No Restore Purchases link is rendered alongside it.

#### Scenario: User owns Remove Ads
- **WHEN** the Home screen renders and `StoreService.hasRemoveAds` is true
- **THEN** the Remove Ads pill is hidden

#### Scenario: Tapping Remove Ads triggers a purchase
- **WHEN** the user taps the Remove Ads pill
- **THEN** the existing purchase flow runs (loading state → success or failure handling), unchanged from v1

### Requirement: Tab switching from Home

The Home screen SHALL participate in a two-tab navigation (Home / Leaderboard) where switching between tabs is initiated either by the user tapping a bottom-nav icon or by a `SwitchToLeaderboard` `NSNotification` posted elsewhere in the app.

#### Scenario: Tap leaderboard icon
- **WHEN** the user taps the trophy icon in the bottom navigation
- **THEN** the Leaderboard view becomes visible

#### Scenario: Tap home icon while on leaderboard
- **WHEN** the user is on the Leaderboard view and taps the house icon in the bottom navigation
- **THEN** the Home view becomes visible

#### Scenario: Programmatic switch to leaderboard
- **WHEN** any code in the app posts the `SwitchToLeaderboard` `NSNotification`
- **THEN** the active tab switches to Leaderboard, regardless of which tab was selected

#### Scenario: Programmatic dismiss to home
- **WHEN** any code posts the `DismissToHome` `NSNotification` while a full-screen cover (e.g., level selection) is presented from Home
- **THEN** that cover is dismissed and the Home view is the topmost view

### Requirement: Visual fidelity to design system

Every visual constant on Home SHALL come from the design-system primitives. Hex literals, hard-coded font names, hard-coded spacing / radius values, and emoji icons used as visual elements SHALL NOT appear in `HomeView.swift`.

#### Scenario: No raw style literal in HomeView
- **WHEN** auditing `HomeView.swift` after this change
- **THEN** every color comes from `Theme.Colors.*`, every font from `Font.cr*`, every spacing/radius from `Theme.Spacing.*` / `Theme.Radius.*`, and the PLAY button uses `.buttonStyle(.crPrimary)` or its circular variant

#### Scenario: No emoji as visual icon
- **WHEN** auditing `HomeView.swift` after this change
- **THEN** no emoji character appears as a visual icon in the body (text labels may still localize emoji content if part of localized copy, but layout icons use SF Symbols or asset images)

### Requirement: Settings sheet entry point

The Home screen SHALL render a gear icon button (`Image(systemName: "gearshape.fill")`, design-system icon style) in the top-right corner of the Home screen. Tapping the gear SHALL present a modal sheet (`SettingsSheet`) hosting the Volume slider, Restore Purchases, and Legal entries.

#### Scenario: Tap gear opens settings
- **WHEN** the user taps the gear icon
- **THEN** a sheet is presented containing the Settings UI

#### Scenario: Settings sheet content
- **WHEN** the Settings sheet is visible
- **THEN** it contains, top to bottom: a "Volume" label + horizontal slider (range 0.0–1.0); a mute warning row visible only when the slider is at 0; a divider; a "Restore Purchases" action button; a "Legal" action button; a close affordance (system swipe-down or X button)

#### Scenario: Volume slider persists across launches
- **WHEN** the user adjusts the volume slider in the Settings sheet
- **THEN** the new value is persisted in `UserDefaults` under the key `cr.appVolume` and restored on next app launch

#### Scenario: Volume scales click + voice audio
- **WHEN** the user moves the volume slider while the app is running
- **THEN** the next UI click sound and the next called-color voice audio are played at a volume scaled by `cr.appVolume`; at 0 both audio paths are inaudible

#### Scenario: Mute warning shown when volume is zero
- **WHEN** the user moves the slider to exactly 0
- **THEN** a warning row is shown below the slider explaining that sound is needed because the called color is announced out loud

#### Scenario: Restore Purchases works from the sheet
- **WHEN** the user taps "Restore Purchases" in the Settings sheet
- **THEN** the existing `StoreService.restore()` flow runs (loading state → success or failure), and `home_restore_purchases_pressed` is logged with telemetry source `settings`

#### Scenario: Legal link works from the sheet
- **WHEN** the user taps "Legal" in the Settings sheet
- **THEN** the device opens `https://nicode.bichu.fr/?lang={en|fr}#privacy` for the user's preferred localization, identical to the prior `MainTabView` legal footer behavior

