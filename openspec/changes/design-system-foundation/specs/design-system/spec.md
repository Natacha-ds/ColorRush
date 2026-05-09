## ADDED Requirements

### Requirement: Theme tokens

The system SHALL expose a `Theme` Swift namespace centralizing every visual constant — colors, spacing, corner radii, shadow definitions, gradients — that the redesigned UI consumes. Call sites SHALL reference `Theme.*` symbols and SHALL NOT inline raw color hex codes, raw point values for spacing/radii, or raw shadow parameters.

#### Scenario: Color token referenced
- **WHEN** a SwiftUI view applies a background color from the design
- **THEN** it references a value under `Theme.Colors.*` (e.g., `Theme.Colors.surface`)
- **AND** no hex literal appears at the call site

#### Scenario: Spacing token referenced
- **WHEN** a SwiftUI view sets padding or spacing
- **THEN** it references a value under `Theme.Spacing.*` (e.g., `Theme.Spacing.medium`)

#### Scenario: Radius token referenced
- **WHEN** a SwiftUI view applies a corner radius
- **THEN** it references a value under `Theme.Radius.*`

#### Scenario: Gradient token referenced
- **WHEN** a SwiftUI view fills with a gradient defined in the design
- **THEN** it references a value under `Theme.Gradient.*` (e.g., `Theme.Gradient.primary`)

### Requirement: Montserrat typography API

The system SHALL bundle the Montserrat font family in the app, register it via `Info.plist` `UIAppFonts`, and expose a `Font` extension with semantic names mapping to the design's typographic scale. Call sites SHALL reference `Font.cr*` symbols and SHALL NOT call `.custom("Montserrat-...", size:)` directly.

#### Scenario: Display title rendered
- **WHEN** a view renders the screen-level display title (e.g., the level intro "BEAT 250")
- **THEN** it uses `Font.crDisplay` (or a more specific display variant)

#### Scenario: Body text rendered
- **WHEN** a view renders descriptive body copy
- **THEN** it uses `Font.crBody`

#### Scenario: Custom font registered
- **WHEN** the app launches
- **THEN** Montserrat font names resolve via `UIFont(name:size:)` (or SwiftUI `Font.custom`) without falling back to the system font

### Requirement: Primary gradient button style

The system SHALL provide a `ButtonStyle` for the primary call-to-action — violet-to-cyan gradient pill — applicable as `.buttonStyle(.crPrimary)` on any standard SwiftUI `Button`. The style SHALL handle the pressed state with a visible feedback (scale or opacity reduction).

#### Scenario: Apply primary style
- **WHEN** a developer writes `Button("Play") { … }.buttonStyle(.crPrimary)`
- **THEN** the button renders with the violet-to-cyan gradient, white bold italic label, and pill shape matching the Figma design

#### Scenario: Pressed feedback
- **WHEN** a user presses and holds a primary button
- **THEN** the button visually responds (scale ≤ 1.0 or reduced opacity) and returns to its idle state on release

### Requirement: Danger gradient button style

The system SHALL provide a `ButtonStyle` for destructive / restart actions — red gradient pill — applicable as `.buttonStyle(.crDanger)`.

#### Scenario: Apply danger style
- **WHEN** a developer writes `Button("Start Over") { … }.buttonStyle(.crDanger)`
- **THEN** the button renders with the red gradient pill matching the Game Over screen design

### Requirement: Icon button style

The system SHALL provide a `ButtonStyle` for circular / square icon-only buttons (close, back, home, trophy nav buttons) applicable as `.buttonStyle(.crIcon)`.

#### Scenario: Apply icon style
- **WHEN** a developer writes `Button { … } label: { Image(systemName: "xmark") }.buttonStyle(.crIcon)`
- **THEN** the button renders with the design's icon-button look (transparent background, themed tint, hit area ≥ 44pt)

### Requirement: Reusable view components

The system SHALL expose reusable SwiftUI view components for the patterns repeated across multiple screens: card container, chip / badge, hearts pill, progress bar, stat badge, section header.

#### Scenario: Card container used
- **WHEN** a screen needs a rounded dark surface containing arbitrary content
- **THEN** it wraps the content in `CRCard { … }` with no further styling

#### Scenario: Hearts pill used
- **WHEN** a screen displays remaining lives
- **THEN** it instantiates `CRHeartsPill(remaining: Int, total: Int)` and the pill renders the heart row plus the count exactly as on the gameplay HUD

#### Scenario: Progress bar used
- **WHEN** a screen displays score progress toward a target
- **THEN** it instantiates `CRProgressBar(progress: Double)` taking a value in `0.0...1.0` and renders the gradient bar

#### Scenario: Stat badge used
- **WHEN** a screen displays a single labeled statistic (Hits / Misses / Streak)
- **THEN** it instantiates `CRStatBadge(label: String, value: String, tone: Tone)` where `tone` selects the colored value treatment (success / warning / accent)

### Requirement: Design system preview screen

The system SHALL include a `DesignSystemPreview` SwiftUI view (compiled in DEBUG builds) that renders every token (colors, gradients, typography scale) and every component variant on a single scrollable canvas, usable both as static `#Preview` and as a runtime debug screen.

#### Scenario: Preview renders all tokens
- **WHEN** a developer opens `DesignSystemPreview` in Xcode preview
- **THEN** it shows the full color palette, the full Montserrat type scale, the gradient swatches, and the spacing/radius scale

#### Scenario: Preview renders all components
- **WHEN** the preview scrolls past the tokens
- **THEN** it shows every component (`CRCard`, `CRChip`, `CRHeartsPill`, `CRProgressBar`, `CRStatBadge`, `CRSectionHeader`) and every button style in idle and pressed states

### Requirement: Existing screens unaffected

The change SHALL be additive. Existing screens (Home, Gameplay, Game Over, Settings, etc.) SHALL continue to render identically to v1 after this change is applied — no visual regression, no behavior change.

#### Scenario: App still builds and runs
- **WHEN** the change is merged
- **THEN** the app builds without errors and every existing screen renders identically to its pre-change appearance

#### Scenario: No call site migrated
- **WHEN** reviewing the diff of this change
- **THEN** no existing screen `View` file is modified to consume the new design system (migration is deferred to subsequent changes)
