## Why

ColorRush ships today with English-only hardcoded UI strings (~80 distinct user-facing strings across `HomeView`, `LeaderboardView`, `LevelGameView`, `RulesView`, `LevelGameOverView`, etc.) and English-only color voice audio (`Red-voice.mp3` etc. in `ColorGame/assetsimage/`). The v1 App Store target market includes France (Tony's home market and primary playtester audience), and shipping the app exclusively in English would underserve that audience and miss obvious low-hanging fruit. Localizing to French + English unlocks France/Belgium/Switzerland/Quebec without requiring full multi-language audio review.

Spanish, German, and Brazilian Portuguese were considered for v1 but deferred — they add review burden (Tony cannot self-QA those locales) and cover smaller marginal markets. The localization mechanism shipped here SHALL be forward-compatible so adding ES/DE/PT-BR later is a copy-paste drop-in.

## What Changes

- Adopt **String Catalog** (`Localizable.xcstrings`, iOS 16+, modern Xcode default) as the localization mechanism. Source language: **English**. Translation language: **French**.
- Wrap all user-facing hardcoded strings in Swift source so SwiftUI's automatic localization resolves them through the catalog. `Text("Best Score")` already works as-is when the catalog has the entry; interpolations and non-`Text` strings get explicit `String(localized:)` or `LocalizedStringKey` treatment.
- Add **French (fr)** to the project's Localizations list in Xcode → Project → Info → Localizations.
- Localize the four color voice audio files: keep the existing 4 mp3s in `en.lproj/`, add 4 French mp3s (`rouge`, `bleu`, `vert`, `jaune`) in `fr.lproj/`. Files keep the same base names so `Bundle.main.url(forResource:withExtension:)` resolves automatically per `Locale.current`.
- Generate the French audio via a quality TTS provider (default: **OpenAI TTS `tts-1-hd`** — cheap, natural, multi-locale). Tony rejected Apple's `AVSpeechSynthesizer` earlier in this session ("la voix fr est horrible"), so the audio is pre-baked, not runtime-synthesized.
- Add **French localization for the 6 Game Center leaderboards** in App Store Connect (manual). Display name strings drafted: "Couleur seule — 5 vies" / "3 vies" / "1 vie", "Couleur + texte — 5 vies" / "3 vies" / "1 vie".
- Add **French localization for the App Store listing** (description, subtitle, keywords, "What's New") in App Store Connect. Tony writes the FR copy after I provide the EN draft.
- The IAP "Remove Ads" remains untouched — already localized in 5 languages from a prior change.
- Fall back gracefully for users in unsupported locales (ES, DE, PT-BR, etc.) — they see the EN copy per Apple's standard fallback chain.

## Capabilities

### New Capabilities

- `i18n`: covers the localization infrastructure — String Catalog usage, source/translation language pair, locale-resolved audio asset lookup, project localizations list, and the fallback contract for unsupported locales. v1 ships EN + FR; the capability is forward-compatible with future locales.

### Modified Capabilities

- `level-gameplay`: the requirement that the app speaks the announced color name during gameplay gains a clarification — the spoken language SHALL match `Locale.current` when an audio file is available for that locale, falling back to English otherwise. Existing semantics (when to speak, which color) are unchanged.

## Impact

- **Code**: ~80 `Text("…")` call sites across ~6 SwiftUI view files get touched (mostly automatic via String Catalog extraction once strings are wrapped). New `Localizable.xcstrings` resource. New `fr.lproj/` resource directory containing 4 mp3 files. No production logic changes outside of confirming `SpeechService` reads from the localized bundle (it already does — `Bundle.main.url(forResource:withExtension:)` is locale-aware).
- **Build**: no new SPM dependency. Xcode handles String Catalog and `.lproj` automatically. Bundle size +~200 KB for the 4 FR mp3s.
- **Runtime / player behavior**: a French-locale device sees French UI throughout and hears French color names. An English (or any other) locale device sees English UI and hears English color names.
- **Persistence**: nothing new. The chosen language follows `Locale.current` (system setting), no in-app override in v1.
- **External dependencies**: optional — OpenAI TTS API call (Tony's key) for the one-time generation of the 4 FR audio files. Once baked, no runtime dependency on the TTS service.
- **Tests**: manual — switching the simulator's language to French should reveal any missing or truncated strings.
- **Production ship dependency**: Tony approves the FR translations + the FR audio quality before merge, and adds the FR strings to App Store Connect (app listing + Game Center leaderboards) before submitting v1 for review.
