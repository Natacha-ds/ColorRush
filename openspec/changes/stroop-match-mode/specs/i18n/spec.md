## ADDED Requirements

### Requirement: Color Match strings are localized in English and French

Every user-facing string introduced by Color Match (mode name and description, color names, answer-button accessibility labels, countdown/ready text, game-over copy, rules text) SHALL have `en` and `fr` entries in `Localizable.xcstrings` with state `translated`.

#### Scenario: French device
- **WHEN** the device language is French and the player opens Color Match
- **THEN** all texts, including the displayed color names, appear in French

#### Scenario: Catalog audit
- **WHEN** the diff is grepped for hard-coded English strings
- **THEN** none remain outside `String(localized:)` / automatic catalog lookup
