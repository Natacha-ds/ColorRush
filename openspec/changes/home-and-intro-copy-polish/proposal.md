## Why

Pre-ship copy and discoverability polish across three surfaces: the Home tagline grew slightly inaccurate ("everything else" suggests tapping every non-matching tile, but the player only ever taps one), the Restore Purchases / Legal links are scattered (footer above tab bar + IAP-only footer on Home) and a future Volume control has nowhere to live, and the level-intro modal silently introduces a per-tap timer at level 3 with no on-screen mention. None of this is a v1 blocker, but bundling these tweaks before submission avoids a follow-up release for copy-only changes.

## What Changes

- **Home tagline** — `Tap everything else.` → `Tap anything else.` (EN). FR is rephrased from the positive framing to a negative one to read as a sharper rule statement: `Une couleur est annoncée. Tape toutes les autres.` → `Une seule règle :\nne touche pas la couleur annoncée.` The cyan-accent treatment on the second part is preserved (EN `anything else.`, FR `la couleur annoncée.`).
- **Settings sheet on Home** — add a gear icon top-right of `HomeView` next to the BEST score block. Tapping opens a sheet (`SettingsSheet`) containing: an audio Volume slider (with a mute warning at zero, since the called color is announced out loud), a Restore Purchases button, and a Legal link.
  - The slider value is persisted as `@AppStorage("cr.appVolume")` (Double, default 1.0) and applied to both `SoundService` (UI clicks + secondary clicks) and `SpeechService` (called-color audio).
  - The existing Legal footer above the tab bar in `MainTabView` is removed (single source of truth for legal/restore).
  - The "Restore Purchases" link inside the IAP footer in `HomeView` is removed (Restore now only lives in the Settings sheet); the Remove Ads pill stays.
- **Audio session: silent-switch override** — `SpeechService.configureAudioSession()` switches from `.ambient` to `.playback` (with `.mixWithOthers`) so the called-color voice prompt keeps playing when the iPhone's silent switch is on. The called color is mechanically required to play; the new in-app volume slider is the user's mute path, with the existing mute warning copy making that explicit. `mixWithOthers` preserves any music the player is running.
- **Mode picker FR copy alignment** — refine the FR descriptions for the Color ONLY and Color and Text mode cards in `LevelSystemSelectionView` to match Tony's wording. EN strings unchanged.
- **Difficulty label rename** — `INSANE` → `MASTER` (display only). `MistakeTolerance.hard` raw value, lives count, and tone color are unchanged so existing local scores and Game Center buckets are untouched.
- **Level-intro per-tap timer banner** — for levels with `timePerResponse != nil` (levels 3+), `LevelIntroView` displays a yellow lightning-bolt banner between the TIME/LIVES card row and the PLAY button: `1.8 seconds max per tap!` (level 3-4), `1.5 seconds max per tap!` (5-6), `1.2 seconds max per tap!` (7-8), `1 second max per tap!` (9-10). Levels 1-2 (no per-tap timer) show no banner and the modal falls back to the existing layout.

## Capabilities

### Modified Capabilities
- `home-screen`: tagline copy, settings sheet entry point, IAP footer simplification.
- `level-system-selection`: difficulty label `MASTER` and FR mode descriptions.
- `level-intro-modal`: per-tap timer banner.

### New Capabilities
- None. Settings live as a sub-section of `home-screen`.

## Impact

- **Modified**:
  - `ColorGame/HomeView.swift` — tagline string, gear icon button, IAP footer trims Restore link, presents `SettingsSheet`.
  - `ColorGame/MainTabView.swift` — removes the Legal footer block above the tab bar.
  - `ColorGame/LevelSystemSelectionView.swift` — `INSANE` → `MASTER` label.
  - `ColorGame/LevelGameView.swift` — `LevelIntroView` body inserts a per-tap timer banner when `currentLevelConfig.timePerResponse != nil`.
  - `ColorGame/SoundService.swift` — reads `cr.appVolume` to scale the click pool master gain.
  - `ColorGame/SpeechService.swift` — reads `cr.appVolume` to scale per-color voice players; `configureAudioSession()` uses `.playback` (was `.ambient`) so the called-color voice plays even when the silent switch is on.
  - `ColorGame/Localizable.xcstrings` — rename `everything else.` key, FR refresh on tagline + mode descriptions, rename `INSANE` to `MASTER`, add settings + per-tap timer entries.
- **Added**:
  - `ColorGame/SettingsSheet.swift` — new presentation sheet hosting Volume slider + Restore + Legal.
- **Unchanged**: `LevelSystemModels.swift`, gameplay logic, IAP / RevenueCat plumbing, `MistakeTolerance` raw values, scoring, leaderboard, Game Center buckets.
- **No new dependencies**.
