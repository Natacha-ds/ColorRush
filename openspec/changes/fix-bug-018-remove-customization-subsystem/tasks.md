## 1. Preparation

- [x] 1.1 Confirmed via grep that all `CustomizeModeSheet` / `CustomizationStore` / `GameCustomization` references live inside the customization subsystem itself plus the orphan `@StateObject` at `LevelGameView.swift:17`
- [x] 1.2 No unexpected hits surfaced; cascade matches the proposal

## 2. Source removal

- [x] 2.1 Deleted `ColorGame/CustomizeModeSheet.swift`
- [x] 2.2 Deleted `ColorGame/CustomizationStore.swift`
- [x] 2.3 Deleted `ColorGame/GameCustomization.swift`
- [x] 2.4 Removed the orphan `@StateObject private var customizationStore = CustomizationStore.shared` from `ColorGame/LevelGameView.swift`

## 3. Validation

- [x] 3.1 Post-deletion grep returns no matches (exit 1)
- [x] 3.2 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 3.3 Simulator smoke test: home → pick a level → game opens in `LevelGameView` and is playable end-to-end

## 4. Commit & archive

- [ ] 4.1 Commit with message `refactor: remove dead customization subsystem (BUG-018)` and reference the OpenSpec change in the body
- [ ] 4.2 Update `AUDIT_BUGS.md` status table: BUG-018 → ✅ Done with the commit hash and archive folder name
- [ ] 4.3 Archive the change via `/opsx:archive fix-bug-018-remove-customization-subsystem`
