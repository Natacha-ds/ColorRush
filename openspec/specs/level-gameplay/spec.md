# level-gameplay Specification

## Purpose

The `level-gameplay` capability covers the rendering and orchestration of a level-based game session — from the moment the player launches a level to its completion or failure. It enforces that exactly one canonical view powers in-game rendering, leaving no room for legacy or alternative game views in the shipped target.
## Requirements
### Requirement: Single canonical level-gameplay view

The application SHALL render any level-based game session exclusively through the `LevelGameView` view. No other game view (legacy or alternative) shall coexist in the compiled `ColorGame` target.

#### Scenario: Starting a game from the selection screen

- **WHEN** the player picks a mode and difficulty in `LevelSystemSelectionView` and taps "Start"
- **THEN** the game session opens in an instance of `LevelGameView` (and no other game view)

#### Scenario: Source code audit

- **WHEN** a developer searches the `ColorGame` target for game-view definitions
- **THEN** only `LevelGameView` is defined; no legacy `struct GameView: View` remains in the module

### Requirement: Level-gameplay session is decoupled from user-tunable customization

The level-gameplay session SHALL run from a fixed, code-defined level configuration and SHALL NOT depend on any user-tunable customization store, persisted preference, or external tuning model for its in-game behavior.

#### Scenario: No customization store on the runtime path

- **WHEN** a developer audits the dependencies of `LevelGameView` and its supporting types
- **THEN** no reference to a `CustomizationStore`, `GameCustomization`, or equivalent user-tunable persistence layer exists on the active runtime path

#### Scenario: Fresh install with no persisted state

- **WHEN** a player launches the app for the first time, with no `UserDefaults` entries set
- **THEN** they can start and complete a level without any customization-related code path executing

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

