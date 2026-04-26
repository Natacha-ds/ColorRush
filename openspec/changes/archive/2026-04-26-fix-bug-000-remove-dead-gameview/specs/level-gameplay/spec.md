## ADDED Requirements

### Requirement: Single canonical level-gameplay view

L'application SHALL rendre toute session de jeu basée sur les niveaux exclusivement via la vue `LevelGameView`. Aucune autre vue de jeu (héritée ou alternative) ne doit coexister dans la cible compilée `ColorGame`.

#### Scenario: Lancement d'une partie depuis l'écran de sélection

- **WHEN** l'utilisateur valide un mode et une difficulté depuis `LevelSystemSelectionView` puis tape "Start"
- **THEN** la session de jeu s'ouvre dans une instance de `LevelGameView` (et aucune autre vue de jeu)

#### Scenario: Audit du code source

- **WHEN** un développeur recherche les définitions de vues de jeu dans la cible `ColorGame`
- **THEN** seule `LevelGameView` est définie ; aucune `struct GameView: View` héritée ne subsiste dans le module
