## Context

ColorRush v1 ships with screen-local styling — colors, fonts, paddings declared inline in each `View`. A full visual redesign is now starting from 9 Figma frames (`screens/`). Without a shared foundation, each migrated screen would either re-import the same constants ad hoc, or diverge stylistically. We want a single source of truth for design tokens and reusable building blocks before any screen migration.

Constraints:
- Pure SwiftUI, no third-party dependency.
- Free Figma plan: no Dev Mode MCP, design source of truth is the PNGs and SVGs in `screens/`.
- Must work side-by-side with existing screens (no breaking change in this phase).
- iOS 16+ (existing project minimum) — no need for `Observation` macro or iOS 17-only APIs.

## Goals / Non-Goals

**Goals:**
- Centralize colors, typography, spacing, radii, shadows in a `Theme` namespace.
- Provide a typed font API based on Montserrat that mirrors the design's typographic hierarchy.
- Provide ButtonStyles and reusable view components for the recurring patterns visible across the 9 frames.
- Ship a SwiftUI preview / debug screen showcasing every token and component, usable both as visual review tool and as living documentation.
- Keep the foundation **additive only** — existing screens compile and run unchanged.

**Non-Goals:**
- Migrate any existing screen to the new design system in this change.
- Introduce dark/light mode toggling — the design is dark-only.
- Implement the gameplay tap animation (light beams) — that belongs to the Gameplay screen migration change.
- Implement the Color Rush logo as a vector — for now we use the PNG provided in `screens/logo.png`. Vectorization can come later if needed.
- Localize component strings — components take `String` inputs; localization happens at call sites in screen-level changes.

## Decisions

### Decision 1: Token surface — `Theme` namespace, not Asset Catalog

Tokens live in Swift code under a `Theme` enum (caseless namespace) with nested enums (`Theme.Colors`, `Theme.Spacing`, `Theme.Radius`, `Theme.Shadow`, `Theme.Gradient`). Colors are declared as `Color(hex:)` literals.

**Why:** Tokens are referenced from code (not Interface Builder), so a Swift namespace gives autocomplete, refactor safety, and one-glance discoverability. Asset Catalog colors are useful for `UIKit`/`UIColor` consumers and asset variants, neither of which apply here.

**Alternative considered:** xcassets-only color set. Rejected — adds indirection without benefit, and tokens like spacing/radii can't live there anyway, splitting the source of truth.

### Decision 2: Typography — typed `Font.cr*` extension, font name registered once

Bundle Montserrat `.ttf` weights, declare them in `Info.plist` `UIAppFonts`, and expose a `Font` extension with semantic names (`.crDisplay`, `.crTitle`, `.crHeadline`, `.crBody`, `.crLabel`, `.crCaption`) plus a few specialized ones for the score / level numbers (`.crScoreHero`).

**Why:** Semantic names decouple call sites from raw font sizes — when the design moves from "BEAT 250" at 36pt to 40pt, we change one constant. Italic vs upright is encoded in the semantic name, not duplicated at every call site.

**Alternative considered:** Use Apple's text styles (`.title`, `.body`) with a `.fontDesign(.rounded)` modifier. Rejected — design uses italic Montserrat which is not an Apple system style, and the visual identity depends on Montserrat specifically.

### Decision 3: Components — `View`s + `ViewModifier`s, no `@Environment` injection

Components are plain `View` structs taking explicit parameters. The `Theme` is statically referenced from inside each component, not injected via `@Environment`.

**Why:** No theme variants planned (no light mode, no per-screen theming). Static reference keeps call sites simple and avoids ceremony for zero benefit. If we later need theming, we can introduce an environment-based override without breaking call sites that already use the static defaults.

**Alternative considered:** Environment-based theme injection. Rejected as YAGNI for v1.

### Decision 4: ButtonStyle protocol over custom Buttons

Primary / Danger / Icon buttons are SwiftUI `ButtonStyle` implementations, applied via `.buttonStyle(.crPrimary)` etc. via static `ButtonStyle` extensions.

**Why:** Standard SwiftUI idiom — preserves accessibility, hit-testing, and the call site keeps using the native `Button(action:)` API. Custom button views would re-implement these for no gain.

### Decision 5: DesignSystemPreview is a real `View`, not just `#Preview`

The preview is exposed as `DesignSystemPreview: View` in the target (debug-only via `#if DEBUG`), with a `#Preview` wrapper. It can be presented at runtime in a debug menu later if needed.

**Why:** Lets us scroll through the showcase live in the simulator, not just static previews. Marginal extra work, large practical value during the redesign.

### Decision 6: Asset organization

Logo lives in `Assets.xcassets/Logo.imageset/`. SVG icons from `screens/assets/` are imported as PDF (or kept as bitmap PNG @1x/@2x/@3x exported from the SVG) into individual imagesets — SwiftUI's `Image("name")` then handles them. SF Symbols are used for generic icons (back arrow, close, hourglass) where a clear semantic equivalent exists.

**Why:** SwiftUI `Image` + Asset Catalog is the path of least resistance and gives `renderingMode` control. SF Symbols give us free dynamic type / multicolor support for generic icons.

## Risks / Trade-offs

- **[Risk]** Montserrat at large display sizes may render slightly differently from the Figma rasterization (kerning, tracking, vertical metrics) → **Mitigation:** validate visually in `DesignSystemPreview` against the screenshots; tune kerning/tracking on the typed `Font.cr*` if needed in a follow-up.
- **[Risk]** Hard-coded hex colors instead of Asset Catalog limit future light-mode support → **Mitigation:** if light mode is ever requested, `Color` extensions can be migrated to dynamic colors with one PR; call sites stay stable because they use `Theme.Colors.*`.
- **[Trade-off]** Components encode style choices that may not fit every future screen perfectly → accepted: the goal is consistency now; one-off variants can take override parameters later as real needs emerge.
- **[Risk]** `.ttf` font files add bundle size (~1.5MB for 5 weights) → acceptable for a game app; acknowledged.

## Migration Plan

This change is purely additive — no migration needed for v1 code. Existing screens stay on their inline styling. Subsequent OpenSpec changes will migrate screens one by one (or in cohesive groups) to consume the design system.

Rollback: deleting `ColorGame/DesignSystem/` and reverting `Info.plist` `UIAppFonts` is sufficient; no other code references the new symbols yet.

## Open Questions

- Final exact spacing scale (4 / 8 / 12 / 16 / 24 / 32 / 48 / 64?) — to confirm by measuring against frames during implementation.
- Whether the gradient stops on the primary button match exactly the Figma values — TBD during preview validation.
