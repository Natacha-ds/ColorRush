## Why

`ColorGame/GameView.swift` (1869 lignes) est du code mort hérité de l'ancien système de jeu. Aucun call-site externe ne le référence — seules la définition `struct GameView: View` (ligne 49) et son `#Preview` final (ligne 1868) le mentionnent. Le runtime utilise exclusivement `LevelGameView` (instancié depuis `LevelSystemSelectionView.swift:153-164`).

Garder ce fichier nuit à la lisibilité, double presque la surface d'audit du module de jeu, et complique l'intégration future des SDKs ads/IAP sur lesquels on doit travailler avant la submission App Store.

## What Changes

- Suppression complète du fichier `ColorGame/GameView.swift`.
- Retrait de toutes les références à `GameView.swift` dans `ColorGame.xcodeproj/project.pbxproj` (sections `PBXFileReference`, `PBXBuildFile`, group children, et `Sources` build phase).
- Aucune modification de comportement runtime : pas de feature flag, pas de release notes utilisateur.
- Aucune migration de données ni d'état persistant.

## Capabilities

### New Capabilities

- `level-gameplay` : capacité couvrant le rendu et le pilotage d'une session de jeu basée sur les niveaux. Cette change l'introduit avec une seule exigence (l'unicité de la vue de jeu) qui sera étendue par les change suivantes (fixes des bugs P0/P1 de l'audit).

### Modified Capabilities

Aucune.

## Impact

- **Code** : `ColorGame/GameView.swift` supprimé, `ColorGame.xcodeproj/project.pbxproj` modifié.
- **Build** : doit rester vert (`xcodebuild ... build` → `BUILD SUCCEEDED`).
- **Runtime** : aucun impact attendu — le fichier n'est référencé nulle part en dehors de lui-même.
- **Dépendances externes** : aucune.
- **Tests** : aucun test n'existe à ce jour, donc rien à mettre à jour.
