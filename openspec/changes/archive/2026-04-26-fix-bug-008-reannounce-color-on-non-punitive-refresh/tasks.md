## 1. Preparation

- [x] 1.1 Confirmed `refreshBoardOnly()` location and the existing "don't speak it again" comment
- [x] 1.2 Confirmed `SpeechService.speak(_:)` stops any in-flight audio at the top (`SpeechService.swift:33`)

## 2. Implementation

- [x] 2.1 Replaced the "don't speak it again" comment in `refreshBoardOnly()` with `speechService.speak(colorName(for: announcedColor))` and updated the surrounding comments

## 3. Validation

- [x] 3.1 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 3.2 Simulator test (level 9 idle): announced color audibly re-spoken on each 1 s refresh
- [x] 3.3 Simulator test (tap mid-refresh): next round announce plays cleanly, no audio glitch
- [x] 3.4 Simulator regression (levels 1-8): unchanged, no extra audio

## 4. Commit & archive

- [x] 4.1 Commit `a8b66a8 fix: re-announce color on non-punitive refresh (BUG-008)`
- [x] 4.2 `AUDIT_BUGS.md` status table updated (BUG-008 → ✅ Done) in the archive commit
- [x] 4.3 Archived via `/opsx:archive` to `2026-04-26-fix-bug-008-reannounce-color-on-non-punitive-refresh`
