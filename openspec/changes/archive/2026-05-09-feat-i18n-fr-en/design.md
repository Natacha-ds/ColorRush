## Context

The codebase ships ~80 distinct hardcoded user-facing strings via SwiftUI `Text("…")`, plus a handful of `String` interpolations like `"Score: \(level.currentScore)"`. There is no current localization mechanism — strings live inline next to the views that render them. The four color voice mp3s (`Red-voice.mp3`, `Blue-voice.mp3`, `Green-voice.mp3`, `Yellow-voice.mp3`) live in `ColorGame/assetsimage/` and are loaded via `Bundle.main.url(forResource: "Red-voice", withExtension: "mp3")` in `SpeechService.swift`.

Xcode 15+ ships **String Catalog** as the modern localization mechanism (file extension `.xcstrings`). It supersedes the old `.strings` format with: (1) graphical Xcode editor showing a key+translations matrix per locale, (2) automatic extraction of `Text(...)` literals at build time, (3) native plural / variable-width support, (4) machine-readable JSON storage for diffability and CI integration. The deployment target is iOS 17+, so adopting it is uncontroversial.

Apple's bundle resolution for resources prefers `<locale>.lproj/<file>` over generic `<file>` based on `Bundle.main.preferredLocalizations` (which derives from `Locale.current` and the project's declared localizations). Dropping the existing 4 mp3s into `en.lproj/` and the new 4 FR mp3s into `fr.lproj/` makes the existing `SpeechService` lookup automatically locale-aware with zero code change.

Tony's home market is France; English is the App Store fallback for any non-supported locale. ES/DE/PT-BR are deferred until a follow-up change.

## Goals / Non-Goals

**Goals:**
- Localize all user-facing UI strings to FR while keeping EN as the source-of-truth and fallback.
- Localize the announced-color voice audio so a French-locale player hears French color names and an English-locale player hears English ones.
- Use the modern Apple-recommended mechanism (String Catalog) so future locales drop in cleanly.
- Make the "no in-app language override" decision explicit — `Locale.current` (system setting) is the only signal in v1.
- Keep the IAP localization (already shipped in 5 languages via App Store Connect) untouched.

**Non-Goals:**
- Spanish, German, Brazilian Portuguese — deferred to a follow-up change once Tony has bandwidth or a reviewer for those locales.
- An in-app language picker. Most casual games rely on `Locale.current`; building a settings UI is out of scope for v1.
- Localizing the IAP product name/description (already done at App Store Connect for 5 locales).
- Auto-translating strings via an LLM at build time. Tony self-translates EN→FR (faster + accurate for a French native speaker).
- Recording human VO for the color audio. TTS-baked audio is acceptable for a 4-word vocabulary in a casual game.

## Decisions

### Use String Catalog (`Localizable.xcstrings`), not `.strings` files

**Decision:** create one `Localizable.xcstrings` at the app root (or under `ColorGame/Resources/`). Source language is **English**. Add **French** as a translation locale via the catalog's UI in Xcode.

**Rationale:** String Catalog is Apple's current convention since iOS 16 / Xcode 15. It auto-extracts strings from `Text("…")` literals at build time, has a graphical editor that shows untranslated keys at a glance, supports plural forms natively, and ships as a single JSON file that's diff-friendly. The legacy `.strings` format requires manual key registration and per-locale file maintenance — strictly worse for our scale.

**Alternative considered:** keep things hardcoded and hand-maintain a `LocalizedStrings.swift` lookup map. Rejected — defeats the auto-extraction benefit and forces every developer to remember the lookup pattern.

### English as source language, French as translation

**Decision:** the catalog declares English as the source locale. Source strings live in `Text("Best Score")` form throughout the codebase. French translations are filled in via the Xcode editor or by editing the `.xcstrings` JSON directly.

**Rationale:** matches the existing code (already EN-hardcoded), matches Apple's App Store fallback convention (apps without a user-locale match show their development/source language), and minimizes diff noise in PRs. Inverting (FR source, EN translation) would require touching every string AND would make the source code less readable for non-French collaborators (and most documentation tools / LLMs).

### Per-locale folders for audio assets, NOT filename-suffix variants

**Decision:** move the existing 4 mp3s from `ColorGame/assetsimage/` to `ColorGame/Resources/en.lproj/` (keeping the base names: `Red-voice.mp3` etc.). Drop the new 4 FR mp3s in `ColorGame/Resources/fr.lproj/` with the **same base names**.

**Rationale:** Apple's `Bundle.main.url(forResource:withExtension:)` API auto-resolves to the locale-appropriate file based on `Bundle.main.preferredLocalizations` (derived from `Locale.current` and the project's declared localizations). The existing `SpeechService.audioFileName(for:)` returns `"Red-voice"`, `"Blue-voice"`, etc. — zero code change is needed; the bundle does the work.

**Alternative considered:** explicit filename suffixes (`Red-voice-en.mp3` / `Red-voice-fr.mp3`) plus a manual locale-to-suffix mapping in `SpeechService`. Rejected — duplicates Apple's built-in mechanism, requires maintenance every time a locale is added, and creates a divergence from the platform-idiomatic pattern.

### Generate FR audio via OpenAI TTS, bake into mp3, ship as static assets

**Decision:** use OpenAI's `tts-1-hd` model (or `gpt-4o-mini-tts` for newer accounts) to synthesize the four French color names ("rouge", "bleu", "vert", "jaune"). Voice: pick a neutral French voice (e.g., `nova` or `shimmer` — both support FR with natural pronunciation). Bake to mp3 at the same bitrate as the existing EN files, ship as static assets in `fr.lproj/`.

**Rationale:** Tony rejected Apple's `AVSpeechSynthesizer` for FR earlier in this session — the OS-bundled compact French voice was "horrible". Pre-baking via a quality TTS gets us audio that matches the EN files in tone and quality, without any runtime cost. OpenAI TTS is cheap (~$0.015 per 1k chars; we have <30 chars total to synthesize, so ~$0.001 in API cost), supports FR natively, and Tony likely already has an API key.

**Alternative considered:** ElevenLabs (premium voices, more natural but ~$5/month subscription); Azure Neural TTS (free tier, slightly more setup). Both are valid; we default to OpenAI for the path-of-least-resistance.

### No in-app language picker — follow `Locale.current`

**Decision:** the chosen locale is whatever the OS reports via `Locale.current`. There is no in-app settings screen to override this in v1.

**Rationale:** casual single-player games typically don't need an override — the user's iOS Settings → General → Language already controls it. Building an in-app picker requires a settings UI, persistence of the override choice, and special handling in `Bundle.main`. Total overkill for v1. If post-launch user feedback asks for it, we'll add it.

**Alternative considered:** offer a toggle in `RulesView`. Rejected — premature, adds testing surface.

### Fallback chain — EN for any non-FR locale

**Decision:** the project declares only `en` and `fr` as supported localizations. iOS automatically falls back to the source language (EN) for any other locale (ES, DE, PT-BR, IT, JA, etc.).

**Rationale:** this is Apple's documented and well-understood fallback pattern. Users in unsupported locales get a working English app rather than a crash, missing strings, or untranslated keys. When we add ES/DE/PT-BR later, just register them in the project's Localizations list and add their translations to the catalog — no logic change.

## Risks / Trade-offs

- **[Risk]** A SwiftUI `Text("…")` is missed during string extraction and ships untranslated. → **Mitigation:** Xcode's String Catalog editor flags untranslated keys with a colored badge, and the build can be configured to warn on missing translations. Tony also visually QAs in FR-locale simulator before merge.
- **[Risk]** A French translation is significantly longer than the English source and breaks UI layout (truncation, wrapped buttons, overlapping elements). → **Mitigation:** standard French→English ratio is ~1.2×. Visual QA in FR locale catches truncation. UI elements with tight widths (e.g., the IAP button at 220×44pt, the "Continue — Watch Ad" at 260×50pt) should be reviewed; expand or use auto-sizing where needed.
- **[Risk]** OpenAI TTS produces an FR audio that doesn't match the timbre / tempo of the existing EN audio (different voice character). → **Mitigation:** Tony auditions the generated mp3s before approving merge. We can re-generate with a different voice / parameters cheaply if the first pass is off.
- **[Risk]** A user with `fr-CA` (Canadian French) or `fr-BE` (Belgian French) locale gets our `fr` translation by default. → **Mitigation:** acceptable for v1. Apple's locale fallback resolves `fr-CA` → `fr` → `en`. If linguistic differences ever matter (rare for our small string surface), we can add `fr-CA.lproj` etc. later.
- **[Trade-off]** Two new audio files per future locale (currently 4) = +200 KB each. For 5 locales total, +800 KB. Acceptable for a casual game (<10 MB total bundle).

## Migration Plan

No runtime migration. The existing 4 mp3s move from `ColorGame/assetsimage/` to `ColorGame/Resources/en.lproj/` (asset reorganization, no bundle-relative path change since `Bundle.main.url(forResource:withExtension:)` is location-agnostic). The 4 FR mp3s ship for the first time in this change.

For users on a French device: the next app launch shows FR UI and plays FR audio automatically. For users on any other device: behavior is unchanged.

**Rollback:** `git revert` the implementation commit. The catalog file is removed, FR audio assets disappear, the project's Localizations list is restored to EN-only, and the views go back to hardcoded EN. The existing 4 EN mp3s would also need to be moved back from `en.lproj/` to `assetsimage/` — which the revert handles atomically.
