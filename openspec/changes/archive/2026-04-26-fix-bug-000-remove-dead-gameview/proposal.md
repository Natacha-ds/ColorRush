## Why

`ColorGame/GameView.swift` (1869 lines) is dead code carried over from the legacy game system. No external call site references it — only the `struct GameView: View` definition (line 49) and its trailing `#Preview` (line 1868) mention it. The runtime exclusively uses `LevelGameView` (instantiated from `LevelSystemSelectionView.swift:153-164`).

Keeping this file hurts readability, nearly doubles the audit surface of the game module, and complicates the upcoming integration of the ads/IAP SDKs we need to land before App Store submission.

## What Changes

- Full removal of the `ColorGame/GameView.swift` file.
- Removal of all `GameView.swift` references in `ColorGame.xcodeproj/project.pbxproj` (`PBXFileReference`, `PBXBuildFile`, group children, and `Sources` build phase) — discovered during apply to be a no-op since the project uses `PBXFileSystemSynchronizedRootGroup`.
- No runtime behavior change: no feature flag, no user-facing release notes.
- No data or state migration.

## Capabilities

### New Capabilities

- `level-gameplay`: capability covering the rendering and orchestration of a level-based game session. This change introduces it with a single requirement (uniqueness of the game view), to be extended by the upcoming changes (P0/P1 fixes from the audit).

### Modified Capabilities

None.

## Impact

- **Code**: `ColorGame/GameView.swift` removed; `ColorGame/ColorTile.swift` added (rescued live `ColorTile` view used by `LevelGameView`).
- **Build**: must remain green (`xcodebuild ... build` → `BUILD SUCCEEDED`).
- **Runtime**: no expected impact — the file is not referenced anywhere outside itself, except for the `ColorTile` view which has been preserved.
- **External dependencies**: none.
- **Tests**: no tests exist today, so nothing to update.
