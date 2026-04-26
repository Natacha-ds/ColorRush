## ADDED Requirements

### Requirement: Level-gameplay session releases all system observers on dismiss

The level-gameplay session SHALL register any system notifications (in particular app background/foreground events) using a mechanism whose lifetime is bound to the SwiftUI view's lifetime, and SHALL NOT leak observers across sessions. After the view is dismissed, no observer registered by that session shall remain active in `NotificationCenter`.

#### Scenario: Single session, single registration

- **WHEN** a player starts a level and the `LevelGameView` materializes
- **THEN** at most one observer per registered notification name is active for that view instance

#### Scenario: Repeated sessions do not accumulate observers

- **WHEN** a player starts and exits five level sessions in a row
- **THEN** at any point during or after, the number of active observers registered by `LevelGameView` is bounded by the number of currently-mounted instances (typically one), independent of how many sessions have been played

#### Scenario: Background event fires the timer pause exactly once

- **WHEN** the app moves to the background while a single `LevelGameView` is mounted
- **THEN** the game timer is paused exactly once, regardless of how many prior sessions have been played in the same launch
