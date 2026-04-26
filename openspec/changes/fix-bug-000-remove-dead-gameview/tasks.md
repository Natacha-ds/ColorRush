## 1. Préparation

- [x] 1.1 Confirmer que Xcode est fermé (évite que le pbxproj soit régénéré pendant l'édition) — non bloquant : le projet utilise des synchronized groups, pas d'édition pbxproj manuelle
- [x] 1.2 Vérifier la présence de références `GameView.swift` dans le pbxproj — **0 occurrence** (synchronized groups, fichiers auto-découverts depuis le filesystem)

## 2. Suppression du code mort

- [x] 2.1 Supprimer le fichier `ColorGame/GameView.swift` (1869 lignes)
- [x] 2.2 ~~Retirer la ligne PBXBuildFile~~ — N/A (synchronized groups)
- [x] 2.3 ~~Retirer la ligne PBXFileReference~~ — N/A (synchronized groups)
- [x] 2.4 ~~Retirer la référence dans le PBXGroup~~ — N/A (synchronized groups)
- [x] 2.5 ~~Retirer la ligne dans la PBXSourcesBuildPhase~~ — N/A (synchronized groups)

## 3. Validation

- [x] 3.1 `grep -rn "GameView" ColorGame ColorGame.xcodeproj` → aucune occurrence pour `GameView` autre que `LevelGameView` et `isGameViewPresented`
- [x] 3.2 `xcodebuild -project ColorGame.xcodeproj -scheme ColorGame -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO` → `BUILD SUCCEEDED`
- [x] 3.3 Lancement dans le simulateur : la home → choix d'un niveau → la partie s'ouvre dans `LevelGameView` et est jouable

## 4. Commit & archive

- [ ] 4.1 Commit avec message `refactor: remove dead GameView.swift (BUG-000)` (corps : référencer la change OpenSpec)
- [ ] 4.2 Mettre à jour `AUDIT_BUGS.md` pour cocher BUG-000 comme traité
- [ ] 4.3 Archiver la change via `/opsx:archive fix-bug-000-remove-dead-gameview` une fois mergée
