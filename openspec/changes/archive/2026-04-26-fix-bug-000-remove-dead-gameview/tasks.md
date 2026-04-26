## 1. Preparation

- [x] 1.1 Confirm Xcode is closed (avoids the pbxproj being regenerated mid-edit) — non-blocking: the project uses synchronized groups, no manual pbxproj edit
- [x] 1.2 Verify presence of `GameView.swift` references in the pbxproj — **0 occurrences** (synchronized groups, files auto-discovered from the filesystem)

## 2. Dead code removal

- [x] 2.1 Remove the file `ColorGame/GameView.swift` (1869 lines)
- [x] 2.2 ~~Remove the `PBXBuildFile` line~~ — N/A (synchronized groups)
- [x] 2.3 ~~Remove the `PBXFileReference` line~~ — N/A (synchronized groups)
- [x] 2.4 ~~Remove the entry in the `PBXGroup`~~ — N/A (synchronized groups)
- [x] 2.5 ~~Remove the entry in `PBXSourcesBuildPhase`~~ — N/A (synchronized groups)

## 3. Validation

- [x] 3.1 `grep -rn "GameView" ColorGame ColorGame.xcodeproj` → no occurrence other than `LevelGameView` and `isGameViewPresented`
- [x] 3.2 `xcodebuild -project ColorGame.xcodeproj -scheme ColorGame -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED`
- [x] 3.3 Simulator launch: home → pick a level → the game opens in `LevelGameView` and is playable

## 4. Commit & archive

- [x] 4.1 Commit `3216f80 refactor: remove dead GameView.swift (BUG-000)`
- [x] 4.2 `AUDIT_BUGS.md` updated (BUG-000 ✅) in the same commit
- [x] 4.3 Archived via `/opsx:archive`
