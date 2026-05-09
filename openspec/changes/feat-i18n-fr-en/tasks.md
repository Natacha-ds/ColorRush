## 1. Manual setup (Tony)

- [x] 1.1 Confirm the **language of the existing 4 mp3s** (`Red-voice.mp3`, `Blue-voice.mp3`, `Green-voice.mp3`, `Yellow-voice.mp3`). If they pronounce English ("red", "blue", "green", "yellow"), they go in `en.lproj/` and we generate FR; if they pronounce French ("rouge", "bleu", "vert", "jaune"), they go in `fr.lproj/` and we generate EN
- [x] 1.2 Provide TTS API access for FR (or EN, depending on 1.1) audio generation. Default: **OpenAI API key** (any plan, ~$0.001 in usage for the four short words). Alternative: Tony bakes the mp3s himself in a separate tool and drops the files in
- [x] 1.3 Approve the resulting audio (audition the 4 generated mp3s for tone, tempo, clarity) before merge
- [x] 1.4 Provide / approve French translations for the ~80 UI strings extracted from the source. I provide the EN string list; Tony fills the FR column (in the Xcode String Catalog editor or by editing `Localizable.xcstrings` JSON directly)
- [x] 1.5 Add **French localization for the 6 Game Center leaderboards** in App Store Connect (per-leaderboard display name + description). Suggested copy: "Couleur seule — 5 vies / 3 vies / 1 vie", "Couleur + texte — 5 vies / 3 vies / 1 vie"
- [x] 1.6 Add **French localization for the App Store listing** in App Store Connect: app subtitle (≤30 chars), description, keywords, "What's New" for v1.0. I draft EN; Tony writes FR

## 2. Xcode project — declare French as a supported localization

- [x] 2.1 Open the Xcode project → **Project (ColorGame)** → **Info** tab → **Localizations** section → **+** → select **French (fr)**. Xcode creates the `.lproj` folder structure
- [x] 2.2 In the Localizations dialog, confirm Storyboards / XIBs (none in this project) and Asset Catalogs are not auto-localized — only String Catalog and per-locale resource folders matter for us

## 3. String Catalog — extract and localize UI strings

- [x] 3.1 Add a new **String Catalog** file at `ColorGame/Resources/Localizable.xcstrings`. Source language: **English (en)**, additional language: **French (fr)**
- [x] 3.2 Build the project once — Xcode auto-extracts every `Text("…")` literal in Swift source into the catalog, populating the EN column with the source string
- [x] 3.3 For non-`Text` strings (alert messages, button labels not using `Text`, navigation titles, etc.), wrap the literal at the call site so it is picked up by the extractor:
  - `Text("Best Score")` — already auto-extracted, no change
  - Use `String(localized: "Final Score")` for non-`Text` calls
  - Use `LocalizedStringKey("Restore Purchases")` for keys passed to UI APIs that accept `LocalizedStringKey`
- [x] 3.4 Survey all hardcoded strings via `grep -rn 'Text("[^"]*")\|String("' ColorGame --include="*.swift"`. Confirm coverage: HomeView, LeaderboardView, LevelGameView (incl. LevelCompleteView, LevelFailedView, LevelGameOverView, FinalWinView), RulesView, MainTabView, LevelSystemSelectionView. ~80 unique strings expected
- [x] 3.5 For interpolated strings (e.g., `Text("Score: \(levelRun.currentScore)")`), use the String Catalog's variable syntax — Xcode handles `%@` / `%lld` placeholders and matches them in the FR translation
- [x] 3.6 Skip pure-symbol strings (emojis used as icons like `Text("🔧 Skip")`, `Text("🌍")`, `Text("✨")` standalone, `"Heart"` image name, etc.) — these are pickup as keys, but the FR translation can be identical to the EN

## 4. Audio — localize color voice mp3s

- [x] 4.1 Create the directory `ColorGame/Resources/en.lproj/` (Xcode auto-creates this when French is added in step 2.1, but we may need to manually add `en.lproj` if only `fr.lproj` was generated)
- [x] 4.2 Move the existing 4 mp3s from `ColorGame/assetsimage/` to `ColorGame/Resources/en.lproj/` (or `fr.lproj/` if Tony's existing audio was actually French — see task 1.1). Keep the same base names: `Red-voice.mp3`, `Blue-voice.mp3`, `Green-voice.mp3`, `Yellow-voice.mp3`
- [x] 4.3 Generate the 4 missing-locale mp3s via OpenAI TTS (or alternative provider per task 1.2). Suggested invocation:
  - For French: `openai api audio.speech.create -m tts-1-hd -v nova --input "rouge"`-style calls; pick a voice that sounds neutral (`nova`, `shimmer`, or `alloy`)
  - Encode at the same bitrate as the existing files (run `afinfo` or `ffprobe` on an existing mp3 first)
- [x] 4.4 Drop the 4 generated mp3s in the **other** lproj folder with the **same base names** as the EN files
- [x] 4.5 Update Xcode's project navigator to reference both `en.lproj/` and `fr.lproj/`. With the synchronized root group convention this project uses (`PBXFileSystemSynchronizedRootGroup`), file system additions auto-sync — verify after the next Xcode open
- [x] 4.6 Update `SpeechService.swift` only if the bundle path resolution does not work as expected. The existing `Bundle.main.url(forResource: fileName, withExtension: "mp3")` call SHOULD already auto-resolve to the locale folder; if it returns nil for the FR locale during testing, investigate `Bundle.main.preferredLocalizations` and the project's declared localizations

## 5. Validation

- [x] 5.1 `xcodebuild -project ColorGame.xcodeproj -scheme ColorGame -destination 'generic/platform=iOS Simulator' build` returns `BUILD SUCCEEDED`
- [x] 5.2 In the simulator, switch the device language to **French** (Settings → General → Language → Français). Re-launch the app
- [x] 5.3 Visual sweep of all screens in FR locale: HomeView, MainTabView, LeaderboardView, RulesView, LevelSystemSelectionView, LevelGameView (during a run), LevelCompleteView, LevelFailedView, LevelGameOverView, FinalWinView. Confirm: no untranslated keys visible, no truncated buttons, no overlapping elements
- [x] 5.4 Audio sweep in FR locale: trigger a round, confirm the color voice plays the French pronunciation. Trigger background/foreground (re-speak), confirm same. Trigger non-punitive refresh on level 9 if available, confirm same
- [x] 5.5 Switch the simulator to a non-supported locale (e.g., **Spanish** or **German**). Re-launch the app. Confirm everything renders in **English** (fallback) and the audio plays the EN mp3s
- [x] 5.6 Switch back to **English**. Re-launch. Confirm full EN coverage and audio
- [x] 5.7 Regression sweep — verify the IAP "Remove Ads" flow still works end-to-end (button label is the App Store Connect localized string, not from our catalog). Verify Game Center auth and submission still work. Verify ads (interstitial cap + rewarded continue) still work

## 6. App Store Connect — submission prep (post-merge)

- [ ] 6.1 In App Store Connect → ColorRush → App Information → Localizable Information, add the **French** localization for: subtitle, description, keywords, support URL (if different), privacy policy URL (if different)
- [ ] 6.2 Add the FR localization for the 6 Game Center leaderboards (display name per leaderboard + optional description) — task 1.5
- [ ] 6.3 Verify the IAP "Remove Ads" FR localization is still in place (was set in a prior change; no work needed here, just confirm)
- [ ] 6.4 (Out of scope of this change but blocks submission) — Tony decides whether FR-locale screenshots are worth uploading or whether EN screenshots are an acceptable fallback for the FR App Store

## 7. Commit & archive

- [x] 7.1 Commit with message `feat: localize app UI and color voice audio to FR + EN (feat-i18n-fr-en)`
- [x] 7.2 No `AUDIT_BUGS.md` entry — feature
- [x] 7.3 Archive via `/opsx:archive feat-i18n-fr-en`
