## Why

ColorRush carries a fully dead customization subsystem inherited from the legacy difficulty-mode tuning UI. A cascade analysis shows three files plus one orphan declaration are unreachable from the live runtime:

- `ColorGame/CustomizeModeSheet.swift` (619 lines) — never instantiated externally
- `ColorGame/CustomizationStore.swift` (142 lines) — only referenced by the dead `CustomizeModeSheet` and by a `@StateObject private var customizationStore = CustomizationStore.shared` in `LevelGameView.swift:17` that is **declared but never read**
- `ColorGame/GameCustomization.swift` (150 lines) — only referenced by `CustomizationStore`
- `LevelGameView.swift:17` — orphan `@StateObject` declaration that instantiates a singleton on every game session for no reason

Total surface: ~912 lines (>12% of the codebase). Removing it makes future audits and the upcoming ads/IAP integration meaningfully cleaner, and eliminates a wasteful singleton instantiation per session.

## What Changes

- Delete `ColorGame/CustomizeModeSheet.swift`
- Delete `ColorGame/CustomizationStore.swift`
- Delete `ColorGame/GameCustomization.swift`
- Remove the orphan `@StateObject private var customizationStore = CustomizationStore.shared` line from `ColorGame/LevelGameView.swift`
- No runtime behavior change visible to the player.
- No data or state migration (`UserDefaults` keys `game.customization` and `level.system.enabled` become unused; legacy data on existing devices is harmless and will be ignored).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `level-gameplay`: ADD a requirement that the level-gameplay session SHALL NOT depend on any user-tunable customization store. The existing requirement (single canonical view) stays untouched.

## Impact

- **Code**: three files removed, one orphan declaration removed from `LevelGameView.swift`.
- **Build**: must remain green (`xcodebuild ... build` → `BUILD SUCCEEDED`).
- **Runtime**: no expected impact — none of the deleted code runs in the live game flow.
- **Memory / launch**: minor improvement (one fewer singleton instantiated per `LevelGameView` mount).
- **Persisted state**: legacy `UserDefaults` entries are orphaned but never read. No migration needed.
- **External dependencies**: none.
- **Tests**: no tests exist today, so nothing to update.
