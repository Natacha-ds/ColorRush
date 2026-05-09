## 1. Rewrite LevelIntroView body

- [x] 1.1 In `ColorGame/LevelGameView.swift`, locate the inline `struct LevelIntroView` (currently at ~lines 1454-1602) and replace its body with the new Frame 4 implementation. Keep the struct's name, properties (`@ObservedObject var levelRun: LevelRun`, `let onDismiss: () -> Void`), and surrounding placement (still inline in this file) unchanged
- [x] 1.2 Add a private `@State var progress: Double = 1.0` for the timer line animation
- [x] 1.3 Add a private constant `static let autoPlayDuration: TimeInterval = 3.0` matching the parent's `DispatchWorkItem` schedule

## 2. Modal scaffold

- [x] 2.1 Outer `ZStack` with a translucent black backdrop (`Color.black.opacity(0.6).ignoresSafeArea()`) and a centered modal `VStack`
- [x] 2.2 Modal container sized `.frame(maxWidth: 320)`, padded `Theme.Spacing.lg`, background `RoundedRectangle(cornerRadius: Theme.Radius.lg).fill(Theme.Colors.surface)`, with a subtle `Theme.Colors.border` 1pt strokeBorder overlay
- [x] 2.3 Inside the modal, a `VStack(spacing: Theme.Spacing.lg)` containing in order: timer line, subtitle, BEAT headline, stats HStack, PLAY button

## 3. Timer line

- [x] 3.1 Render a `GeometryReader { geo in ... }` containing a leading-aligned filled `RoundedRectangle(cornerRadius: 2)` with `fill(Theme.Gradient.primary)` and `frame(width: geo.size.width * CGFloat(progress), height: 3)`
- [x] 3.2 Wrap the GeometryReader in a fixed `frame(height: 3)` and clip to a `RoundedRectangle(cornerRadius: 2)` so it doesn't overflow during animation
- [x] 3.3 On `.onAppear`, run `withAnimation(.linear(duration: Self.autoPlayDuration)) { progress = 0.0 }`

## 4. Subtitle ("LEVEL XX - WARM UP")

- [x] 4.1 Compute `private var subtitle: String { … }` returning `"Level NN - Warm up"` for `levelRun.currentLevel` 1 or 2, otherwise `"Level NN"` (zero-padded with `String(format: "Level %02d", n)`)
- [x] 4.2 Render the subtitle as `Text(subtitle)` with `.font(.crLabel)`, `.textCase(.uppercase)`, `.foregroundStyle(Theme.Colors.textSecondary)`, multilineTextAlignment center

## 5. BEAT headline

- [x] 5.1 Render the headline as a concatenated `Text` expression: `Text("BEAT ").foregroundStyle(Theme.Colors.textPrimary) + Text("\(levelRun.getRequiredScore())").foregroundStyle(Theme.Colors.accentSecondary)`
- [x] 5.2 Apply `.font(.crDisplay)` to the resulting `Text` view, multilineTextAlignment center

## 6. Stats cards (TIME + LIVES)

- [x] 6.1 Implement `private var formattedTime: String` returning `MM:SS` from `levelRun.currentLevelConfig?.durationSeconds ?? 0` (e.g., 30 → "00:30", 90 → "01:30"); falls back to "—:—" when config is nil
- [x] 6.2 Implement TIME card: VStack with "TIME" label (`.crLabel`, textSecondary, uppercase) and the formatted time (`.crTitle`, textPrimary), padded `Theme.Spacing.md`, background `Theme.Colors.surfaceElevated` rounded `Theme.Radius.md`
- [x] 6.3 Implement LIVES card: VStack with "LIVES" label and a hearts HStack — render `levelRun.mistakeTolerance.totalLives` SF symbol `heart.fill` icons; the first `levelRun.remainingLives` use `Theme.Colors.danger`, the rest use `Theme.Colors.danger.opacity(0.18)`. Same surface treatment as TIME card
- [x] 6.4 Wrap both cards in an `HStack(spacing: Theme.Spacing.md)` with each card `.frame(maxWidth: .infinity)` so they share the row evenly

## 7. PLAY button

- [x] 7.1 Render `Button { onDismiss() } label: { HStack(spacing: Theme.Spacing.sm) { Image(systemName: "play.fill"); Text("Play") } }.buttonStyle(.crPrimary)`
- [x] 7.2 Configure the play arrow with `.font(.system(size: 18, weight: .bold))` so it scales correctly inside the primary button label

## 8. Cleanup

- [x] 8.1 Removed the v1 elements: 3 stars (Bigstar / Mediumstar images), pink "Targeted score" card with E60076 hex literals, "Targeted" / "score" two-line text, score container with FFC9C9 fill, bomb-icon description row, X close button
- [x] 8.2 Removed the v1 `levelDescription` computed property (no longer referenced after the rewrite)
- [x] 8.3 Confirmed no top-level `Color(hex:)` references remain in the new body — every color comes from `Theme.Colors.*`

## 9. Verification

- [x] 9.1 Build the app with `xcodebuild` and confirm BUILD SUCCEEDED with no new warnings
- [x] 9.2 Run the unit test suite (`-only-testing:ColorGameTests -parallel-testing-enabled NO`) — **TEST SUCCEEDED**
- [ ] 9.3 Open `LevelGameView` in Xcode preview (or a dedicated `LevelIntroView` preview if needed); visually compare against `screens/Frame 4.png`; verify the timer line depletes over ~3 seconds and the modal layout matches — **manual review by Tony**
- [ ] 9.4 Launch on simulator: PLAY → mode → difficulty → LET'S GO → modal renders → wait 3s → game starts. Then start another level → modal renders again → tap PLAY in the modal before timer ends → game starts immediately — **manual review by Tony**
- [x] 9.5 Audit the rewritten `LevelIntroView` body: no hex literal, no hard-coded font name, no decorative star/bomb image, no X button — confirmed clean
- [x] 9.6 Audit the diff: only the inline `LevelIntroView` struct body changed; the rest of `LevelGameView.swift` (`startLevel()`, `dismissLevelIntroAndStart()`, `pendingIntroDismiss` mechanics) is NOT modified
