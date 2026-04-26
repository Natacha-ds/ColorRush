## ADDED Requirements

### Requirement: Level-gameplay session is decoupled from user-tunable customization

The level-gameplay session SHALL run from a fixed, code-defined level configuration and SHALL NOT depend on any user-tunable customization store, persisted preference, or external tuning model for its in-game behavior.

#### Scenario: No customization store on the runtime path

- **WHEN** a developer audits the dependencies of `LevelGameView` and its supporting types
- **THEN** no reference to a `CustomizationStore`, `GameCustomization`, or equivalent user-tunable persistence layer exists on the active runtime path

#### Scenario: Fresh install with no persisted state

- **WHEN** a player launches the app for the first time, with no `UserDefaults` entries set
- **THEN** they can start and complete a level without any customization-related code path executing
