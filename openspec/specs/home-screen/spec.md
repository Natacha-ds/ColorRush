# home-screen Specification

## Purpose
TBD - created by archiving change home-screen-redesign. Update Purpose after archive.
## Requirements
### Requirement: Home screen layout

The Home screen SHALL render the following elements, vertically stacked on a black background, matching Frame 1: a "BEST" label and the user's overall best score in the top-left corner; the Color Rush logo image centered; a tagline reading "A color is called. Tap everything else." with the second sentence styled in the brand cyan accent; a circular gradient PLAY button centered as the primary call-to-action; a compact IAP footer (Remove Ads pill + Restore Purchases link) below the PLAY button, hidden when the entitlement is held; a custom bottom navigation bar with two icons (house, trophy).

#### Scenario: Best score visible
- **WHEN** the Home screen renders and the user has at least one recorded score
- **THEN** the top-left of the screen shows "BEST" in a small uppercase label and the score number underneath in a bold italic display style

#### Scenario: No best score yet
- **WHEN** the user has never completed a level
- **THEN** the top-left shows "BEST" with a placeholder dash ("—") in place of the score

#### Scenario: PLAY enters the difficulty flow
- **WHEN** the user taps the PLAY button
- **THEN** the existing level/difficulty selection flow is presented as a full-screen cover (current behavior preserved)

#### Scenario: Tagline content
- **WHEN** the Home screen renders
- **THEN** the tagline reads "A color is called. Tap everything else." with the phrase "everything else" rendered in the brand cyan accent color

### Requirement: IAP entry on Home

The Home screen SHALL expose the Remove Ads single-payment purchase and a Restore Purchases action below the PLAY button, with a compact / footer-style treatment, only when the user does not already hold the entitlement.

#### Scenario: User does not own Remove Ads
- **WHEN** the Home screen renders and `StoreService.hasRemoveAds` is false
- **THEN** a Remove Ads pill (showing the localized price) and a Restore Purchases link are visible below the PLAY button

#### Scenario: User owns Remove Ads
- **WHEN** the Home screen renders and `StoreService.hasRemoveAds` is true
- **THEN** neither the Remove Ads pill nor the Restore Purchases link is visible

#### Scenario: Tapping Remove Ads triggers a purchase
- **WHEN** the user taps the Remove Ads pill
- **THEN** the existing purchase flow runs (loading state → success or failure handling), unchanged from v1

#### Scenario: Tapping Restore triggers a restore
- **WHEN** the user taps the Restore Purchases link
- **THEN** the existing restore flow runs, unchanged from v1

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

