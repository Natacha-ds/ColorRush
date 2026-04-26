## Context

`ColorGame.xcodeproj/project.pbxproj` utilise des `PBXFileSystemSynchronizedRootGroup` (Xcode 16+) : les fichiers sources ne sont **pas listés manuellement** dans le pbxproj, ils sont découverts automatiquement depuis le système de fichiers à chaque build. Ainsi :

- Aucun `PBXBuildFile` / `PBXFileReference` à supprimer pour `GameView.swift`.
- Supprimer le fichier sur disque suffit : Xcode et `xcodebuild` recalculent leur graphe de sources au prochain build.

Cette découverte (faite à l'application de la change) simplifie l'opération : un seul fichier touché côté repo (`ColorGame/GameView.swift` supprimé), zéro édition pbxproj.

## Goals / Non-Goals

**Goals:**
- Supprimer `ColorGame/GameView.swift` du repo et du projet Xcode de manière atomique.
- Garantir que `xcodebuild ... build` reste vert après la suppression.
- Ne **rien** modifier d'autre que ces deux fichiers.

**Non-Goals:**
- Refactoriser quoi que ce soit dans `LevelGameView.swift` ou ailleurs.
- Réorganiser le pbxproj (groupes, ordre des fichiers).
- Toucher à `GameView.swift.xcuserstate` ou tout autre artefact dérivé.

## Decisions

### Édition manuelle du pbxproj plutôt que via Xcode UI

**Décision** : éditer `project.pbxproj` directement avec des `Edit` ciblés sur les 4 sections concernées.

**Rationale** : l'édition via Xcode UI nécessiterait une interaction graphique non scriptable, et produirait probablement le même diff modulo l'ordre des UUIDs. L'édition manuelle est traçable dans le commit et idempotente.

**Alternative écartée** : utiliser `xcodeproj` Ruby gem ou `pbxproj` CLI tools. Ajouterait une dépendance dev pour un one-shot. Pas justifié.

### Stratégie de validation

**Décision** : double vérification — (a) `grep` post-suppression pour s'assurer qu'aucune référence à `GameView` ne subsiste, (b) `xcodebuild build` pour confirmer la compilation.

**Rationale** : le grep attrape les régressions de type "référence implicite oubliée", le build attrape les ruptures de project graph.

## Risks / Trade-offs

- **[Risque]** Le pbxproj contient des UUIDs comme `C652A42A2ED33AC00017BE76` qu'on doit identifier précisément pour `GameView.swift`. → **Mitigation** : grep `GameView.swift` dans le pbxproj pour collecter les UUIDs avant édition, puis vérifier qu'aucune référence ne subsiste après.

- **[Risque]** Conflit potentiel avec le `.xcuserstate` (état UI utilisateur d'Xcode) qui mentionne le fichier ouvert. → **Mitigation** : ce fichier est déjà gitignored (commit `8306a24`), donc aucun impact côté repo.

- **[Trade-off]** L'édition manuelle du pbxproj est fragile à long terme si Xcode régénère le fichier. Pour cette change one-shot, le risque est nul (on fait le diff, on commit, on ferme Xcode au préalable si besoin).

## Migration Plan

Aucune migration nécessaire. La change est binaire : avant/après identiques en runtime, le code mort disparaît.

**Rollback** : `git revert` du commit, le fichier et ses entrées pbxproj reviennent en l'état.
