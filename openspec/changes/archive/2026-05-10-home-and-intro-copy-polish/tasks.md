## 1. Tagline copy (EN + FR)

- [x] 1.1 In `HomeView.swift::tagline`, change `Text("everything else.")` → `Text("anything else.")`
- [x] 1.2 In `Localizable.xcstrings`, rename the key `"everything else."` → `"anything else."`. EN value: `anything else.` / FR value: `la couleur annoncée.` (state translated). FR is rephrased to highlight the rule subject (negative framing) instead of the action target (positive framing).
- [x] 1.3 Update the FR translation of the existing `"A color is called.\nTap "` key from `Une couleur est annoncée.\nTape ` to `Une seule règle :\nne touche pas `. The EN value (`A color is called.\nTap `) stays unchanged.

## 2. Settings sheet + Volume slider

- [x] 2.1 Add `ColorGame/SettingsSheet.swift` containing a `View` with: a "Volume" label + horizontal `Slider(value: $appVolume, in: 0...1)` + a mute warning row visible only when volume == 0; a divider; a "Restore Purchases" button (calls `StoreService.shared.restore()`); a "Legal" button (opens the existing `https://nicode.bichu.fr/?lang={en|fr}#privacy` URL via `openURL`)
- [x] 2.2 Persist the slider with `@AppStorage("cr.appVolume") var appVolume: Double = 1.0`
- [x] 2.3 In `HomeView.swift`, replace the leading-only `bestScoreHeader` HStack with a row that places `BEST` on the left and a gear icon button (`Image(systemName: "gearshape.fill")` styled as `.crIcon`) on the right; tapping the gear sets `isSettingsPresented = true` and presents `SettingsSheet` via `.sheet(isPresented:)`
- [x] 2.4 In `HomeView.swift::iapFooter`, remove the "Restore Purchases" Button (and its `triggerRestore` call site if it's now unused — keep `triggerRestore` if SettingsSheet calls into it via a closure, otherwise inline into the sheet)
- [x] 2.5 In `MainTabView.swift`, delete the `legalFooter` view + its placement in the body (Legal lives in the Settings sheet now)
- [x] 2.6 In `SoundService.swift`, read `UserDefaults.standard.double(forKey: "cr.appVolume")` (defaulting to 1.0 when key absent) at each `play(_:)` to scale the player's `volume = clickVolume * appVolume`
- [x] 2.7 In `SpeechService.swift`, read the same key and scale each player's `volume` before `play()` is invoked
- [x] 2.7.1 In `SpeechService.configureAudioSession()`, change the category from `.ambient` to `.playback` (keeping `.mixWithOthers`) so the called-color voice keeps playing when the iPhone silent switch is on. The volume slider in Settings is the user's mute path; the existing mute-warning copy already explains why audio is required.
- [x] 2.8 Localize the new strings: `Settings`, `Volume`, `Sound is needed to play — the called color is announced out loud.`, `Restore Purchases` (already in catalog — verify), `Legal` (already in catalog — verify)
- [x] 2.9 Log events: `home_settings_pressed` (open), `settings_volume_changed` (slider release), `settings_restore_pressed`, `settings_legal_pressed`

## 3. FR mode description copy alignment

- [x] 3.1 Update FR translation of `A color is called. Tap any square that's not that color.` to `Une couleur est annoncée. Tape sur n'importe quel carré qui n'est pas de cette couleur.`
- [x] 3.2 Update FR translation of `Each square has a color and a word. Tap only when neither matches the called color.` to `Chaque carré a une couleur et un mot. Tape seulement quand ni l'un ni l'autre ne correspond à la couleur annoncée.`

## 4. Difficulty label rename INSANE → MASTER

- [x] 4.1 In `LevelSystemSelectionView.swift`, change `MistakeTolerance.hard.brandLabel` from `"INSANE"` to `"MASTER"`
- [x] 4.2 In `Localizable.xcstrings`, rename the key `"INSANE"` → `"MASTER"`. EN value: `MASTER` / FR value: `MASTER` (state translated, comment updated to reflect the rename)
- [x] 4.3 Verify `MistakeTolerance.hard.rawValue` and `MistakeTolerance.totalLives` are unchanged (one life, danger tone)

## 5. Per-tap timer banner in LevelIntroView

- [x] 5.1 In `LevelGameView.swift::LevelIntroView`, add a `perTapTimerBanner` view rendered between the TIME/LIVES `HStack` and the PLAY button
- [x] 5.2 The banner SHALL render only when `levelRun.currentLevelConfig?.timePerResponse != nil`
- [x] 5.3 The banner SHALL contain: a yellow `Image("CRLightning")` (template, `Theme.Colors.warning` tint) sized 20×20pt + a localized text `"X seconds max per tap!"` (or `"1 second max per tap!"` for level 9-10) where `X` is `formattedTimePerTap` derived from `currentLevelConfig.timePerResponse`
- [x] 5.4 FR text uses comma decimal: `1,8 secondes max par coup !`, `1,5 secondes max par coup !`, `1,2 secondes max par coup !`, `1 seconde max par coup !`. EN uses dot decimal and pluralizes seconds (`1.8 seconds max per tap!`, `1 second max per tap!` for the 1.0 case)
- [x] 5.5 Add Localizable.xcstrings entries (one key per level pair to keep the catalog readable, since pluralization rules differ EN vs FR for 1 second)

## 6. Verification

- [x] 6.1 `xcodebuild build` succeeds with no new warnings
- [x] 6.2 `xcodebuild test ... -only-testing:ColorGameTests -parallel-testing-enabled NO` passes
- [x] 6.3 Audit `Localizable.xcstrings` diff: every new EN key has a `state: translated` FR entry; every removed key has no orphaned reference in code; accents intact (`é`, `à`, `'`)
- [x] 6.4 Audit FR-locale device manual pass (Tony): tagline reads `Une seule règle : / ne touche pas la couleur annoncée.`, mode cards read the new descriptions, difficulty card reads `MASTER`, level 3 intro shows the yellow lightning banner, settings sheet reachable from gear icon, slider at 0 mutes both clicks and called-color audio. Verify the called-color voice keeps playing with the silent switch on.
- [x] 6.5 Confirm `MistakeTolerance.hard` rawValue not modified — pre-existing local scores in the `INSANE` bucket continue to load and rank under `MASTER` label
