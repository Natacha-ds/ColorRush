## ADDED Requirements

### Requirement: Bottom navigation bar component

The system SHALL provide a `CRTabBar` SwiftUI component that renders a horizontally laid-out set of icon-only tab items at the bottom of the screen, with per-item brand color, hit area ≥ 44pt, and selection state driven by an external binding. The bar SHALL respect the bottom safe area inset.

#### Scenario: Tab bar reflects selection
- **WHEN** the parent view binds `CRTabBar(selection: $tab, items: [...])` and `tab` changes
- **THEN** the corresponding item's icon visually highlights (selected style) and the others render in the unselected style

#### Scenario: Tap toggles selection
- **WHEN** the user taps a tab item
- **THEN** the bound selection state updates to that item's identifier

#### Scenario: Per-item tint
- **WHEN** a tab item is configured with a custom selected tint color (e.g., gold for the trophy item)
- **THEN** the selected state renders with that color, not the default accent

#### Scenario: Hit area
- **WHEN** the user taps anywhere within a 44×44pt area centered on a tab icon
- **THEN** the tap registers (no need to hit the icon glyph precisely)

#### Scenario: Safe area
- **WHEN** the device has a home indicator / bottom safe area inset
- **THEN** the tab bar renders above the inset, with the icons fully visible and not clipped
