# ColorRush

iOS game (Swift / SwiftUI). Live on App Store Connect.

## Localization — always check translations

The app ships in **French + English**. Whenever you add, change, or remove user-facing copy, you MUST also update the localization catalog.

- **String catalog**: `ColorGame/Localizable.xcstrings` (Xcode 15+ format, source language = `en`).
  - Every new user-facing string needs `en` + `fr` entries with `state: "translated"`.
  - When you change an existing string's English value, re-translate the `fr` entry — don't leave it in `state: "stale"` or out of sync.
  - When you remove a string from code, remove its entry from the catalog too.
- **Audio assets**: voice prompts live in `ColorGame/Resources/en.lproj/` and `ColorGame/Resources/fr.lproj/`. If you add a new spoken color/word, both lproj folders need the matching `.mp3`.

Before declaring a UI task done: grep the diff for hard-coded English strings (`Text("…")`, button labels, accessibility labels, alerts) and confirm each one is going through `String(localized:)` / SwiftUI's automatic catalog lookup, with both `en` and `fr` populated.

## Workflow

- OpenSpec discipline: one change per feature in `openspec/changes/`, archived under `openspec/changes/archive/` once shipped.
- Commits: `feat: ship <change-name>` for the implementation, `chore: archive <change-name>` for the archive move.
- Never push to `origin` without Tony's explicit go-ahead.
