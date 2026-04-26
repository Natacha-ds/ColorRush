## Context

The customization subsystem was originally designed to let users tune per-difficulty parameters (round timeout, max mistakes, confusion speed) via a `CustomizeModeSheet` UI, with values persisted by `CustomizationStore` to `UserDefaults`. After the level-system refactor (`Remove Old/New toggle and enforce new level system only`), the level system became fixed (10 hardcoded levels in `LevelSystemConfig`) and no UI surface ever instantiates `CustomizeModeSheet` anymore. The store and its model became orphans.

`LevelGameView.swift:17` keeps a `@StateObject private var customizationStore = CustomizationStore.shared` that is declared but never read in the rest of the file. SwiftUI still constructs this singleton at every view mount, which is the only thing keeping the dead code "live" enough that a naïve grep can mistake it for in-use.

`ColorGame.xcodeproj` uses `PBXFileSystemSynchronizedRootGroup` (Xcode 16+), so deleting Swift files from disk is sufficient to remove them from the build — no pbxproj edit needed (lesson learned from the previous change `fix-bug-000-remove-dead-gameview`).

## Goals / Non-Goals

**Goals:**
- Remove the entire dead customization subsystem (three files + orphan declaration) atomically.
- Keep the build green with no runtime behavior change.

**Non-Goals:**
- Migrate or clean up persisted `UserDefaults` keys (`game.customization`, `level.system.enabled`) — they are harmless orphans on existing devices.
- Replace the deleted code with any "future placeholder" for IAP-driven customization.
- Refactor `LevelGameView.swift` beyond removing the orphan line at `:17`.

## Decisions

### Bundle the cleanup into a single change

**Decision**: ship all four edits in one OpenSpec change rather than splitting per file.

**Rationale**: the four edits form a tight cascade — each piece is dead only because the others are. Splitting would create intermediate states where the build still works but the rationale is harder to follow. One change reads as one cohesive cleanup.

**Alternative rejected**: split into "remove unused declaration" + "remove store" + "remove sheet" + "remove model". Adds review overhead with no benefit.

### Leave legacy `UserDefaults` keys behind

**Decision**: do not delete or migrate the `game.customization` and `level.system.enabled` keys from `UserDefaults` on existing devices.

**Rationale**: the keys become unused but are not read anywhere. Adding migration code would introduce risk for zero observable benefit. iOS will eventually let them expire when the app is uninstalled.

**Alternative rejected**: ship a migration that explicitly removes the keys. Not justified — adds risk and code for no user-visible win.

### Verification strategy

**Decision**: triple check — (a) post-deletion `grep` for each removed type name, (b) `xcodebuild build`, (c) simulator smoke test (home → start a level → playable).

**Rationale**: matches the verification pattern from `fix-bug-000-remove-dead-gameview` — grep catches forgotten references, build catches type-resolution breaks, simulator catches behavior regressions.

## Risks / Trade-offs

- **[Risk]** A symbol from these files might be referenced via string-based reflection (`NSClassFromString`, `Selector(...)` for SwiftUI bindings) that grep can miss. → **Mitigation**: low likelihood for SwiftUI/Swift code (no Objective-C runtime use observed in the project); the build step would catch it.

- **[Risk]** Removing `customizationStore = CustomizationStore.shared` from `LevelGameView.swift:17` could break if the singleton has a side effect at `init()` that the running game silently depends on. → **Mitigation**: inspecting `CustomizationStore.init()` shows it just loads `UserDefaults` values into local state — no global side effect. Running the simulator post-fix confirms no regression.

- **[Trade-off]** A future "customization for IAP" feature will need to be rebuilt from scratch, but starting from a clean slate is a feature, not a bug, given the legacy code's tight coupling to a defunct difficulty-mode model.

## Migration Plan

No runtime migration needed. The change is binary at the code level: before/after are functionally identical for users.

**Rollback**: `git revert` the implementation commit. The deleted files come back, the orphan `@StateObject` line returns, and the spec delta in `openspec/specs/level-gameplay/spec.md` can be unwound by a follow-up `MODIFIED` requirement if needed.
