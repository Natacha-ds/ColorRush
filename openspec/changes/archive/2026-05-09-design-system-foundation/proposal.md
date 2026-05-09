## Why

ColorRush v1 has shipped on App Store Connect. The next milestone is a full visual redesign based on 9 Figma frames delivered in `screens/`. Before migrating any screen, we need a shared SwiftUI design system — tokens, typography, button styles, reusable components — so that subsequent screen-by-screen migrations stay coherent and don't each reinvent their own styling. Without this foundation, the redesign would either drift across screens or pile up duplicated styling code that becomes painful to evolve.

## What Changes

- Introduce a `Theme` namespace exposing design tokens: colors (background, surfaces, accents, semantic), spacing scale, corner radii, shadows, gradients.
- Bundle the **Montserrat** font family (Black Italic, Bold Italic, Bold, Medium, Regular) and expose a typed `Font.cr*` API mirroring the design's typographic scale (display, title, headline, body, label, caption).
- Provide shared `ButtonStyle`s: `PrimaryGradientButtonStyle` (violet→cyan), `DangerGradientButtonStyle` (red), `IconButtonStyle`.
- Provide reusable view components used across multiple screens: `CRCard`, `CRChip`, `CRHeartsPill`, `CRProgressBar`, `CRStatBadge`, `CRSectionHeader`.
- Add a `DesignSystemPreview` SwiftUI preview / debug screen that showcases every token and component for visual validation.
- Existing app screens are **not** migrated in this change. They keep their current implementation; the new design system is additive and will be consumed by per-screen migration changes.

## Capabilities

### New Capabilities
- `design-system`: Shared visual foundation (tokens, typography, button styles, reusable components) consumed by all screens during and after the redesign.

### Modified Capabilities
<!-- None. No existing requirement changes; this change only adds the foundation. -->

## Impact

- **New code**: `ColorGame/DesignSystem/` directory with `Theme/`, `Typography/`, `Components/`, `Buttons/`, `Preview/` subfolders.
- **New assets**: Montserrat `.ttf` files added to bundle; logo PNG copied into asset catalog.
- **`Info.plist`**: declare `UIAppFonts` entries for the bundled Montserrat weights.
- **No runtime behavior change**: existing screens stay on their current styling; nothing is removed or rewired in this change.
- **No new dependencies**: pure SwiftUI, no external packages.
