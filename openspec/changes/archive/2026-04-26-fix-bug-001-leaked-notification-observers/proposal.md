## Why

`LevelGameView` registers two `NotificationCenter` observers per session (`UIApplication.willResignActiveNotification` and `didBecomeActiveNotification`) but never removes them, due to a mismatch between the closure-based registration API and the selector-based removal API. As a result, observers accumulate without bound in `NotificationCenter.default` across game sessions, and every backgrounding/foregrounding event fires `pauseTimer()` / `resumeTimer()` once for every past session — on captured state from disposed view instances.

This is a real memory leak with a plausible crash path on long-running sessions or rapid view churn. It is also a likely cause of subtle pause/resume bugs that the player can hit by alt-tabbing during gameplay. Both make the app unsafe to ship to the App Store as-is, and even more dangerous once ad/IAP SDKs (which add their own observers and view churn) are integrated.

## What Changes

- Remove the broken `setupBackgroundNotifications()` and `removeBackgroundNotifications()` helper methods from `LevelGameView`.
- Remove the corresponding `.onAppear` / `.onDisappear` invocations of those methods.
- Add `.onReceive(NotificationCenter.default.publisher(for: ...))` modifiers on the view body for `willResignActive` and `didBecomeActive`, calling `pauseTimer()` and `resumeTimer()` respectively.
- Keep cross-platform compatibility (UIKit on iOS, AppKit on macOS) via the existing `#if canImport(UIKit)` / `#elseif os(macOS)` guards, applied to the notification name only.
- No change to `pauseTimer()` / `resumeTimer()` themselves.
- No public API change; behavior visible to the player remains the same except that the bug stops firing handlers N times.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `level-gameplay`: ADD a requirement that the level-gameplay session SHALL not accumulate `NotificationCenter` observers across sessions, and SHALL release every registered system observer when the view is dismissed.

## Impact

- **Code**: ~65 lines removed (`setupBackgroundNotifications` + `removeBackgroundNotifications` + their two call sites), ~10 lines added (the `.onReceive` modifiers with platform guards).
- **Build**: must remain green (`xcodebuild ... build` → `BUILD SUCCEEDED`).
- **Runtime behavior**:
  - Same: backgrounding pauses the game timer, foregrounding resumes it.
  - Different (better): handlers fire once per event instead of N-times where N is the number of past sessions.
- **External dependencies**: none. Uses Combine and SwiftUI APIs already available.
- **Tests**: no tests exist today, so nothing to update.
