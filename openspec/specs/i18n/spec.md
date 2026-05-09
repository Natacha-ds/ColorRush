# i18n Specification

## Purpose
TBD - created by archiving change feat-i18n-fr-en. Update Purpose after archive.
## Requirements
### Requirement: Localization mechanism is a String Catalog with English source

The app SHALL ship a single `Localizable.xcstrings` (String Catalog) file declaring **English** as the source language. All user-facing UI strings rendered by SwiftUI views SHALL be reachable from this catalog so the build-time extraction picks them up automatically.

#### Scenario: A `Text("…")` literal is registered in the catalog

- **WHEN** a SwiftUI view renders `Text("Best Score")` in source code
- **THEN** the build-time string extraction adds the key `"Best Score"` to `Localizable.xcstrings`, the source language entry is `Best Score`, and the French entry is filled in by Tony before merge

#### Scenario: A non-`Text` string is rendered

- **WHEN** a button label, navigation title, alert message, or other non-`Text` string needs localization
- **THEN** the call site SHALL use `String(localized: "…")` or wrap a `LocalizedStringKey` so the string is picked up by the same catalog

### Requirement: Project declares English and French as supported localizations

The Xcode project's Localizations list (under Project → Info → Localizations) SHALL include exactly two entries: **English (en)** as the development region and **French (fr)** as a translation locale. No other locales SHALL ship in v1.

#### Scenario: A French-locale device reads the catalog

- **WHEN** the app launches on a device with `Locale.current.identifier` resolving to `fr`, `fr-FR`, `fr-CA`, `fr-BE`, or any other French variant
- **THEN** SwiftUI uses the catalog's `fr` translations for all `Text("…")` and `String(localized:)` lookups

#### Scenario: An unsupported-locale device falls back to English

- **WHEN** the app launches on a device whose locale is not French (e.g., `es-ES`, `de-DE`, `pt-BR`, `it-IT`, `ja-JP`)
- **THEN** SwiftUI falls back to the source language (English) for all string lookups, and no untranslated-key artifacts are visible to the user

### Requirement: Color voice audio is locale-resolved via Apple's bundle mechanism

The four announced-color voice mp3s SHALL ship inside per-locale resource folders (`en.lproj/Red-voice.mp3`, `en.lproj/Blue-voice.mp3`, etc., and the same four base names under `fr.lproj/`). The existing `SpeechService` lookup (`Bundle.main.url(forResource:withExtension:)`) SHALL automatically resolve to the locale-appropriate file based on `Locale.current` and the project's declared localizations.

#### Scenario: French-locale player hears French color names

- **WHEN** the app runs on a French-locale device and `SpeechService.speak("red")` is invoked
- **THEN** `Bundle.main.url(forResource: "Red-voice", withExtension: "mp3")` resolves to `fr.lproj/Red-voice.mp3` (which pronounces "rouge"), and that audio is played

#### Scenario: English-locale player hears English color names

- **WHEN** the app runs on an English-locale device and `SpeechService.speak("red")` is invoked
- **THEN** the same lookup resolves to `en.lproj/Red-voice.mp3` (which pronounces "red"), and that audio is played

#### Scenario: Unsupported-locale player hears English color names

- **WHEN** the app runs on a non-FR / non-EN locale device (e.g., German, Spanish)
- **THEN** the bundle resolution falls back to the development region (English), and `en.lproj/Red-voice.mp3` is played

### Requirement: French audio quality matches English audio

The four French color voice mp3s SHALL be generated via a quality TTS service (default: OpenAI `tts-1-hd`) and SHALL be auditioned and approved by Tony for tone, tempo, and clarity before merge. They SHALL be encoded at the same bitrate and codec as the existing English mp3s so the runtime audio playback path remains uniform.

#### Scenario: Tony rejects an FR audio sample

- **WHEN** Tony auditions a generated mp3 and finds it noticeably different in quality / tone from the EN counterpart
- **THEN** the offending file is regenerated (different voice, different parameters, or different provider) and re-auditioned before merge

### Requirement: The app does not provide an in-app language override in v1

The chosen language SHALL follow `Locale.current` (the OS-level setting). There SHALL be no in-app picker, settings toggle, or override mechanism in v1.

#### Scenario: Player switches device language at the OS level

- **WHEN** the player changes their iOS Settings → General → Language to French (or back to another language)
- **THEN** the app reflects the new language on the next launch with no in-app interaction required

