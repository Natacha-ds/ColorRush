## 1. Preparation

- [x] 1.1 Confirmed in-game Back chevron at lines 200-218 with `endGameSession(); dismiss()` body
- [x] 1.2 Confirmed `LevelFailedView` body only renders "Try Again" inside `if failedReason == .insufficientScore`
- [x] 1.3 Confirmed `LevelCompleteView` body only renders the primary "Next Level" / "Finish Run" button
- [x] 1.4 Confirmed parent `LevelCompleteView` call site (line 140-142) had bare `dismiss()` for `onBackToHome`

## 2. In-game Back chevron — save before dismiss

- [x] 2.1 In-game Back chevron now runs `endGameSession()`, then computes `totalScore`, saves to leaderboard if > 0, resets run stats and current level/active flags, then `dismiss()`

## 3. LevelFailedView — render Back to Home button

- [x] 3.1 Secondary "Back to Home" text button rendered below "Try Again", inside the same `if failedReason == .insufficientScore` block, wired to `onBackToHome`

## 4. LevelCompleteView — render Back to Home button + fix parent callback

- [x] 4.1 Secondary "Back to Home" text button rendered below the "Next Level" / "Finish Run" primary CTA in `LevelCompleteView`'s body, wired to `onBackToHome`
- [x] 4.2 Parent call site for `LevelCompleteView`'s `onBackToHome` (line 140) now uses the canonical save-then-reset-then-dismiss closure (matches `LevelFailedView`'s call site)

## 5. Validation

- [x] 5.1 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 5.2 Simulator (in-game Back): chevron exits cleanly, score saved, lands on Home tab
- [x] 5.3 Simulator (LevelFailedView): both buttons rendered; Back to Home saves and lands on Home tab
- [x] 5.4 Simulator (LevelCompleteView): both buttons rendered; Back to Home saves and lands on Home tab
- [x] 5.5 Simulator regression: primary CTAs unchanged
- [x] 5.6 Simulator (transition smoothness): single-animation dismissal — no flash of the LevelSystemSelectionView (achieved by relying on the parent fullScreenCover cascade rather than calling `dismiss()` on `LevelGameView` itself)

## 6. Commit & archive

- [ ] 6.1 Commit with message `fix: render and wire Back to Home across all exit paths (BUG-022)` and reference the OpenSpec change in the body
- [ ] 6.2 Update `AUDIT_BUGS.md` status table: BUG-022 → ✅ Done with the commit hash and archive folder name
- [ ] 6.3 Archive the change via `/opsx:archive fix-bug-022-render-and-wire-back-to-home`
