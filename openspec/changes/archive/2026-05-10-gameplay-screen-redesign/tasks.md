## 1. Tile rendering — system colors + directional white highlight

- [x] 1.1 Tile fill uses the canonical system tile colors directly (`.red` / `.blue` / `.green` / `.yellow`) — Tony walked back the brand `Theme.Colors.Tile.*` palette as too desaturated; the brand tile namespace was removed from the foundation. Game logic in `Tile.isValidHard(...)` continues to compare system colors as before
- [x] 1.2 Restyle `ColorTile.body`: replace the v1 `cornerRadius: 20` with `Theme.Radius.lg`, drop the v1 outer shadow, drop the inner shadow attempt; add a directional white highlight via `strokeBorder(LinearGradient(white→clear from topLeading to bottomTrailing), lineWidth: 2)` to suggest a 3D light-from-top-left effect. Tile size bumped 120 → 150pt to match Frame 5
- [x] 1.3 Same restyle on the inline `ColorAndTextTile` struct in `LevelGameView.swift`; keep the existing label contrast helper (yellow → black, others → white); restyle the label font to `.crHeadline` (BoldItalic 18pt); drop the v1 text shadow

## 2. Tile interaction — switch from Button to gesture

- [x] 2.1 Replace `Button(action:) { … }.buttonStyle(PlainButtonStyle())` with a `SpatialTapGesture` (iOS 17+) on the tile shape — the SwiftUI Button press-state was making the tile flash transparent on tap; gesture-based taps avoid that
- [x] 2.2 The tile's `action` closure signature changes from `() -> Void` to `(CGPoint) -> Void`; the gesture provides `event.location` in tile-local coords so the burst can fire from the exact tap point

## 3. Tap burst animation — CAEmitterLayer via UIViewRepresentable

- [x] 3.1 Add `Pow` (https://github.com/EmergeTools/Pow) as a Swift Package dependency — installed for potential future use (level success burst, button shimmer); Pow is **not** used for the tap burst itself, see 3.2
- [x] 3.2 First iteration used Pow's `.changeEffect(.spray)`; abandoned because it produced sparkle-shaped particles, not the radial light-rays Tony wanted from Frame 5. Switched to a SwiftUI `Canvas` + `TimelineView` approach with multi-stroke glow rays. Iterated on length / count / speed / blend-mode based on Tony's feedback
- [x] 3.3 Final iteration: ditched the Canvas entirely in favor of a UIKit `CAEmitterLayer` adapted from Tony's snippet — radial spark burst, programmatic radial-gradient `Spark` image generated once at module load, base color derived from the tapped tile's color, ranges (0.3 / 0.21 / 0.6) for natural color variation per particle. `emissionLatitude/Longitude` zeroed for true radial dispersal; small `yAcceleration: 50` for slight gravity feel
- [x] 3.4 SwiftUI/UIKit bridge via `CRSparkEmitterView: UIViewRepresentable` hosting a `UIView` whose layer hosts ephemeral `CAEmitterLayer` instances — one per burst, auto-removed 4 seconds after fire so they don't accumulate
- [x] 3.5 Trigger queue: `[CRSparkBurstSpec]` `@State` array; each new spec (identified by `id`) fires once via the Coordinator's `lastSeen` tracking. Unseen specs are filtered each `updateUIView` so multiple simultaneous bursts (streak celebration) all fire in parallel
- [x] 3.6 Particle count scales with `levelRun.currentStreak`: `min(300, streak * 2)` — 1st correct = 2 particles, 5th = 10, 10th = 20, 20th = 40, 50th = 100, capped at 300 (streak ≥ 150). Wrong taps reset the streak via existing game logic, so the next correct tap restarts at 2
- [x] 3.7 Streak celebration: when `levelRun.lastBonusEarned > 0` (existing streak-bonus event), fire **four** simultaneous bursts at the four tile centers, one per tile color (red / blue / green / yellow). Hooked into the existing `.onChange(of: levelRun.lastBonusEarned)` block

## 4. HUD top — back arrow + SCORE + hearts pill

- [x] 4.1 Preserve the v1 back-arrow cleanup logic verbatim (endGameSession + score submission to LeaderboardStore + GameCenterService + run reset + interstitial + DismissToHome notification); only the visual is restyled to `.crIcon` style — the back arrow is **not** a simple `dismiss()` because the v1 cleanup is required for proper exit
- [x] 4.2 Top HUD row: `HStack` with back-arrow button (`.crIcon`), SCORE label + number `VStack`, `Spacer()`, `CRHeartsPill(remaining:total:)`, dev-only Skip button (restyled with `.crCaption` + `Theme.Colors.warning` outline)
- [x] 4.3 Below the top HUD: "TARGET: N" `.crLabel` `Theme.Colors.accentSecondary` + `CRProgressBar(progress: targetProgress)` with `.animation(.easeOut, value: levelRun.currentScore)`. `targetProgress` clamps `currentScore / requiredScore` to [0, 1]

## 5. Mid section — LEVEL title + countdown

- [x] 5.1 Render the level title as `Text(String(format: "LEVEL %02d", levelRun.currentLevel))` with `.font(.crDisplay)`, `.textCase(.uppercase)`, `Theme.Colors.textPrimary`
- [x] 5.2 Below the title, an `HStack` with SF Symbol `hourglass` (cyan) + "N SEC LEFT" `.crLabel` `Theme.Colors.textSecondary` (or `Theme.Colors.danger` when ≤ 5s)
- [x] 5.3 Dropped the v1 "Time Remaining" subtitle and the LinearGradient on the level title

## 6. Round-time progress bar (conditional)

- [x] 6.1 Render only when `levelConfig.hasTimeLimit && !levelConfig.isNonPunitiveRefresh`. Thin (3pt) horizontal bar above the tile grid; `Theme.Colors.surfaceElevated` background; fill `Theme.Colors.success` (≥ 30%) or `Theme.Colors.danger` (< 30%); width = `roundTimeRemaining / timePerResponse`
- [x] 6.2 `.animation(.linear(duration: 0.1), value: roundTimeRemaining)` to mirror v1 smoothness

## 7. Tile grid + spark emitter integration

- [x] 7.1 Tile grid lives in a `ZStack { CRSparkEmitterView; VStack { tile rows } }` with the emitter sized `crBurstAreaSize × crBurstAreaSize` (420pt) — the canvas is larger than the tile grid so spark bursts have room to fly out beyond the tile bounds without clipping
- [x] 7.2 Tile tap gesture provides `event.location` in tile-local coords; `tapPositionInCanvas(forTile:tapLocation:)` converts to the emitter's coordinate space so the burst fires exactly at the tap point
- [x] 7.3 Explicit `.zIndex(0)` on emitter and `.zIndex(1)` on tile VStack to ensure the emitter (with active particles) renders BEHIND the tiles
- [x] 7.4 `crTileGridSpacing = Theme.Spacing.lg` (16pt), `crTileSide = 150pt`

## 8. Background and cleanup

- [x] 8.1 Removed the v1 per-level cosmic `Image("Level\(levelRun.currentLevel)")` background
- [x] 8.2 Set the outer `ZStack` background to `Theme.Colors.background.ignoresSafeArea()`
- [x] 8.3 Removed v1 padding magic numbers around the gameplay HUD; uses `Theme.Spacing.*` tokens
- [x] 8.4 Between levels: `clearAllSparkBursts()` is invoked from `.onChange(of: showLevelIntro)` (when becomes true) — empties the burst queue and bumps `sparkClearToken`. The emitter view watches the token and removes all CAEmitterLayer sublayers, killing in-flight particles so they don't leak across level transitions

## 9. Verification

- [x] 9.1 Build the app with `xcodebuild` and confirm BUILD SUCCEEDED with no new warnings
- [x] 9.2 Unit tests via `xcodebuild test ... -only-testing:ColorGameTests -parallel-testing-enabled NO` — TEST SUCCEEDED
- [x] 9.3 Visual review by Tony — iterated on tile size (120 → 150), shadow vs border (drop inner shadow → directional white highlight), particle library (Pow → CAEmitterLayer), particle count scaling (×100 → ×2 with cap 300), lifetime (1.1 → 3.0), velocity (95 → 55), tap precision (tile center → exact tap point via `SpatialTapGesture`)
- [x] 9.4 Manual sim verification by Tony: tap tiles → particles emit from exact tap point in radial dispersion, streak progressively increases particle count, streak bonus triggers 4 simultaneous bursts at all 4 tile centers, particles wiped between levels, tile remains opaque on tap (no flash)
- [x] 9.5 Audited the rewritten active gameplay portion of `LevelGameView`: no hex literal, no hard-coded font name, no raw point spacing, no `Image("Level…")` reference, no emoji as visual icon (the dev-only Skip button label dropped its 🔧 emoji)
- [x] 9.6 Audited the diff: `LevelSystemModels.swift`, `Tile.swift`, `RulesView.swift`, and other gameplay-state files are NOT modified; only `ColorTile.swift` (visual restyle), the active gameplay portion of `LevelGameView.swift` (visual rewrite + spark emitter additions), `project.pbxproj` (Pow SPM dependency), and `LevelGameView.swift::ColorAndTextTile` (visual restyle) are touched
