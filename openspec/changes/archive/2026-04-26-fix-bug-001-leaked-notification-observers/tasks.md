## 1. Preparation

- [x] 1.1 Re-read `LevelGameView.swift:441-448` — confirmed `.onAppear` calls `setupBackgroundNotifications()` (line 443) and `.onDisappear` calls `removeBackgroundNotifications()` (line 447), surrounding `startLevel()` / `endGameSession()`
- [x] 1.2 Re-read `LevelGameView.swift:1269-1329` — confirmed both helpers had UIKit and macOS branches (closure-based add, selector-style remove)

## 2. Replace manual observers with `.onReceive`

- [x] 2.1 Used `#if canImport(UIKit)` / `#elseif os(macOS)` to keep platform-conditional notification names inline in the view body (no extracted constant needed since each branch has only two modifiers)
- [x] 2.2 Added `.onReceive(NotificationCenter.default.publisher(for: <willResignActive>)) { _ in pauseTimer() }` to the view body, after `.onDisappear`
- [x] 2.3 Added the symmetric `.onReceive(... for: <didBecomeActive>) { _ in resumeTimer() }`
- [x] 2.4 Removed the call to `setupBackgroundNotifications()` from `.onAppear`
- [x] 2.5 Removed the call to `removeBackgroundNotifications()` from `.onDisappear`
- [x] 2.6 Deleted the `setupBackgroundNotifications()` method
- [x] 2.7 Deleted the `removeBackgroundNotifications()` method

## 3. Validation

- [x] 3.1 `grep -n "addObserver\|removeObserver\|setupBackgroundNotifications\|removeBackgroundNotifications" ColorGame/LevelGameView.swift` returns no matches (exit 1)
- [x] 3.2 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 3.3 Simulator behavior smoke test: confirmed background → foreground deducts elapsed time from `timeRemaining` (anti-cheat behavior preserved). Naming of `pauseTimer`/`resumeTimer` is misleading but unchanged in this scope.
- [x] 3.4 Simulator regression test: 5+ sessions opened/closed, then background/foreground cycle — single elapsed-time deduction observed (not N stacked), confirming the leak is gone

## 4. Commit & archive

- [x] 4.1 Commit `2c37b0b fix: remove leaked NotificationCenter observers (BUG-001)`
- [x] 4.2 `AUDIT_BUGS.md` status table updated (BUG-001 → ✅ Done) in the archive commit
- [x] 4.3 Archived via `/opsx:archive` to `2026-04-26-fix-bug-001-leaked-notification-observers`
