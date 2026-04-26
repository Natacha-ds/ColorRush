## Context

The current `LevelGameView` lifecycle for system notifications is:

```swift
// inside LevelGameView body
.onAppear { startLevel(); setupBackgroundNotifications() }
.onDisappear { endGameSession(); removeBackgroundNotifications() }

// helper methods (~60 lines, lines 1269-1329)
private func setupBackgroundNotifications() {
    NotificationCenter.default.addObserver(
        forName: UIApplication.willResignActiveNotification,
        object: nil, queue: .main
    ) { _ in pauseTimer() }
    // ... same for didBecomeActive, plus #elseif macOS branch
}

private func removeBackgroundNotifications() {
    NotificationCenter.default.removeObserver(
        self,                       // ← a struct value
        name: UIApplication.willResignActiveNotification,
        object: nil
    )
    // ... same for the rest
}
```

The bug has two compounding causes:

1. The closure-based `addObserver(forName:object:queue:using:)` returns an `NSObjectProtocol` token. The token is the **only** handle that can be passed to `removeObserver(_:)` to unregister the closure. The current code discards it.
2. `removeObserver(self, name:, object:)` only matches observers registered with `addObserver(_:selector:name:object:)` (the legacy selector API), where `self` is a class instance acting as the observer. `LevelGameView` is a `struct`, and the closure registration above doesn't go through this path. So the call is effectively a no-op.

Because `.onAppear` runs every time the view materializes (level start, retry, navigation back into the screen), each session leaks two observers. Each call to `pauseTimer()` / `resumeTimer()` from the closure captures the view's `self` and its `@State` — references that may already be stale by the time the observer fires.

`ColorGame.xcodeproj` uses Xcode 16+ synchronized groups; no pbxproj edit is needed for this change.

## Goals / Non-Goals

**Goals:**
- Eliminate the observer leak entirely. After fix, the count of registered observers in `NotificationCenter.default` for these two notifications must be bounded by the count of currently-mounted `LevelGameView` instances (typically 1).
- Preserve the existing visible behavior: backgrounding pauses, foregrounding resumes.
- Use idiomatic SwiftUI so the lifecycle is impossible to misuse later.

**Non-Goals:**
- Refactor `pauseTimer()` / `resumeTimer()` themselves.
- Touch unrelated parts of `LevelGameView` (e.g., the round timer, the game timer setup).
- Add `[weak self]` or other class-style memory plumbing — `LevelGameView` is a `struct`, that idiom does not apply.
- Add automated tests (no test infrastructure exists today; deferred to a later, scoped change).

## Decisions

### Use SwiftUI's `.onReceive` modifier on the view body

**Decision:** replace `setupBackgroundNotifications()` / `removeBackgroundNotifications()` with two `.onReceive(NotificationCenter.default.publisher(for: ...))` modifiers in the view body.

**Rationale:** `.onReceive` ties the subscription to the SwiftUI view's lifetime. SwiftUI subscribes when the view materializes and **automatically cancels** the subscription when the view leaves the hierarchy. There is no token to track and nothing to leak by construction. This makes the bug structurally impossible to reintroduce.

```swift
.onReceive(NotificationCenter.default.publisher(for: backgroundNotificationName)) { _ in
    pauseTimer()
}
.onReceive(NotificationCenter.default.publisher(for: foregroundNotificationName)) { _ in
    resumeTimer()
}
```

Cross-platform support stays as a small `#if`-guarded constant for the notification names, instead of duplicating the entire setup block twice.

### Alternatives considered

**Alternative A: keep manual setup/remove, store tokens in `@State`.**
```swift
@State private var observers: [NSObjectProtocol] = []
// setup: observers.append(NotificationCenter.default.addObserver(...))
// remove: observers.forEach { NotificationCenter.default.removeObserver($0) }; observers.removeAll()
```
*Rejected*: works correctly, but it reproduces in 25 lines what SwiftUI already does in zero. It also keeps an imperative pattern that future contributors can break in subtle ways (e.g., calling setup twice without remove in between).

**Alternative B: extract an `ObservableObject` that owns the observer lifecycle.**
*Rejected*: adds a new type, an `@StateObject` declaration, and a `deinit` for two notifications. Disproportionate.

### Cross-platform handling

Keep `#if canImport(UIKit)` / `#elseif os(macOS)` guards, but reduce them to selecting a single `Notification.Name` value used by both `.onReceive` modifiers. The publisher and modifier code itself becomes platform-agnostic.

## Risks / Trade-offs

- **[Risk]** `.onReceive` runs the handler synchronously on the main queue when the publisher emits. The previous code explicitly used `queue: .main`, so behavior matches; but if the publisher ever ran on a different scheduler in the future (e.g., due to a debounce/throttle), `pauseTimer()` would need re-checking. → **Mitigation:** call sites stay on the publisher as written; if future modifiers are added (debounce, throttle), they must keep `.receive(on: RunLoop.main)`.

- **[Risk]** A future developer might add a `@State` or external observer expecting the old setup/remove function to still exist. → **Mitigation:** the design.md and the new spec requirement document the policy; anyone introducing new observers should follow the same `.onReceive` pattern.

- **[Trade-off]** `.onReceive` does not give a handle to introspect or cancel programmatically. This is fine for our use case (no need to stop listening mid-session) but worth noting if future logic ever needs conditional listening.

## Migration Plan

No runtime migration. The change is binary at the code level: before/after are functionally identical for users (other than the leak going away).

**Rollback:** `git revert` the implementation commit. The old (broken) `setupBackgroundNotifications` / `removeBackgroundNotifications` come back, and the spec delta in `openspec/specs/level-gameplay/spec.md` can be unwound by a follow-up `MODIFIED` requirement.
