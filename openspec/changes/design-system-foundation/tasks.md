## 1. Setup & assets

- [x] 1.1 Create `ColorGame/DesignSystem/` directory tree (`Theme/`, `Typography/`, `Buttons/`, `Components/`, `Preview/`)
- [x] 1.2 Download Montserrat weights (Black Italic, Bold Italic, Bold, Medium, Regular) from Google Fonts and add `.ttf` files to `ColorGame/DesignSystem/Typography/Fonts/`
- [x] 1.3 Add Montserrat `.ttf` files to the Xcode target (Copy Bundle Resources) — auto-handled by `PBXFileSystemSynchronizedRootGroup` (Xcode 16+)
- [x] 1.4 Declare Montserrat font filenames under `UIAppFonts` in `Info.plist`
- [x] 1.5 Copy `screens/logo.png` to `Assets.xcassets/CRLogo.imageset/` with proper @1x/@2x/@3x scales (or single image marked Universal)
- [x] 1.6 Import key SVG icons from `screens/assets/` into `Assets.xcassets` — **deferred to per-screen migration changes**: foundation showcases use SF Symbols (`heart.fill`, `house.fill`, `trophy.fill`, `chevron.left`, `xmark`, `arrow.clockwise`, `play.fill`); custom-designed icons (Skull from Frame-3, Lightning+sparkles from Frame-7) will be brought into the asset catalog by the screens that actually use them

## 2. Theme tokens

- [x] 2.1 Create `Theme/Theme.swift` declaring the `Theme` enum namespace
- [x] 2.2 Create `Theme/Theme+Colors.swift` with the canonical palette (one constant per actual hex value): `background`, `surface`, `surfaceElevated`, `border`, `borderStrong`, `textPrimary`, `textSecondary`, `textMuted`, `accent`, `accentSecondary`, `success` (also drives Rookie cue + Hits stat + green tile), `warning` (also drives Misses stat + level-failed header), `danger` (also drives Insane cue + hearts), `pro` (gold; also drives yellow tile + leader badge), plus logo gradient stops and game-over wash, plus a nested `Tile` namespace exposing `red`, `blue`, `green` (= `success`), `yellow` (= `pro`)
- [x] 2.3 Add a `Color(hex:)` initializer helper in `Theme/Color+Hex.swift`
- [x] 2.4 Create `Theme/Theme+Spacing.swift` with the spacing scale (`xs`, `sm`, `md`, `lg`, `xl`, `xxl`)
- [x] 2.5 Create `Theme/Theme+Radius.swift` with the corner radius scale (`sm`, `md`, `lg`, `pill`)
- [x] 2.6 Create `Theme/Theme+Shadow.swift` with the shadow definitions
- [x] 2.7 Create `Theme/Theme+Gradient.swift` exposing `primary` (violet→cyan), `danger` (red), `progress` (red→yellow→cyan), `logo` (white→orange→magenta→cyan), `headerSuccess` (green), `headerFailed` (orange) `LinearGradient` values

## 3. Typography

- [x] 3.1 Create `Typography/Font+ColorRush.swift` exposing semantic `Font.cr*` cases: `crDisplay`, `crLogo`, `crTitle`, `crHeadline`, `crScoreHero`, `crBody`, `crLabel`, `crCaption`, plus italic variants where relevant
- [x] 3.2 Add a small runtime check in `DEBUG` that asserts Montserrat fonts are registered at app launch (logs a warning if missing) — implemented in `FontRegistration.swift`, wired in `ColorGameApp.init()`

## 4. Button styles

- [x] 4.1 Create `Buttons/PrimaryGradientButtonStyle.swift` (violet→cyan pill, white bold italic label, pressed scale feedback)
- [x] 4.2 Create `Buttons/DangerGradientButtonStyle.swift` (red pill variant)
- [x] 4.3 Create `Buttons/IconButtonStyle.swift` (transparent, 44pt min hit area, themed tint)
- [x] 4.4 Create `Buttons/ButtonStyle+Aliases.swift` with static extensions enabling `.buttonStyle(.crPrimary)`, `.crDanger`, `.crIcon`

## 5. Reusable components

- [x] 5.1 Create `Components/CRCard.swift` (rounded surface container accepting `@ViewBuilder` content, optional border, optional shadow)
- [x] 5.2 Create `Components/CRChip.swift` (pill chip with text + optional leading icon + tone enum)
- [x] 5.3 Create `Components/CRHeartsPill.swift` (`remaining: Int`, `total: Int` — renders the hearts row + count from the gameplay HUD)
- [x] 5.4 Create `Components/CRProgressBar.swift` (`progress: Double` clamped 0…1, gradient fill, animated update)
- [x] 5.5 Create `Components/CRStatBadge.swift` (`label`, `value`, `tone` — renders the Hits/Misses/Streak card)
- [x] 5.6 Create `Components/CRSectionHeader.swift` (small uppercase label above content, optional step indicator like "STEP 1/2")

## 6. Preview / showcase

- [x] 6.1 Create `Preview/DesignSystemPreview.swift` — scrollable view rendering: full color palette swatches with names, gradient swatches, full typography scale samples, spacing/radius rulers
- [x] 6.2 Extend `DesignSystemPreview` with sections for every component variant and every button style in idle + pressed states
- [x] 6.3 Add a `#Preview` block at the bottom of `DesignSystemPreview.swift` for Xcode previews

## 7. Verification

- [x] 7.1 Build the app in Xcode and confirm no warnings/errors — `xcodebuild ... build` returned **BUILD SUCCEEDED** with no new warnings
- [x] 7.2 Open `DesignSystemPreview` in Xcode preview and visually compare each token/component against the matching screenshot in `screens/` — validated by Tony 2026-05-09; iterations on the primary/danger button gradient (3-stop, slight tilt, drop shadow) settled
- [x] 7.3 Run the existing test suite (`ColorGameTests`, `ColorGameUITests`) and confirm zero regression — `xcodebuild test ... iPhone 17` returned **TEST SUCCEEDED** with all existing tests passing
- [x] 7.4 Launch the app on the simulator and confirm every existing screen renders identically to before — change is purely additive (no existing screen file modified except `ColorGameApp.swift` for the DEBUG-only font assertion); validated by Tony
- [x] 7.5 Verify Montserrat fonts load (no silent fallback to system font in `DesignSystemPreview`) — `CRFontRegistration.verify()` asserts in DEBUG if any font fails to register; preview rendering with Montserrat confirmed visually by Tony
