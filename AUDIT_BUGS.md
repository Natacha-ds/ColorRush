# ColorRush — Audit de bugs (2026-04-19)

Backlog priorisé issu de l'audit du code vivant du projet.

**Méthode** : audit agentique sur `LevelGameView.swift`, `LevelSystemModels.swift` et fichiers connexes, croisé avec les arbitrages de spec du 2026-04-19 (code = source de vérité).

**Convention** :
- 🔴 P0 — Bloquant pour la submission App Store (crash, perte de données, scoring cassé)
- 🟠 P1 — Logique de jeu visiblement incorrecte par le joueur
- 🟡 P2 — UX dégradée
- 🔵 P3 — Tech debt à traiter avant ads/IAP

Chaque bug est destiné à devenir une `change` OpenSpec individuelle.

---

## 🔴 P0 — Bloquants App Store

### BUG-001 — NotificationCenter observers fuités
- **Fichier** : `LevelGameView.swift:1270-1330`
- **Symptôme** : memory leak sur chaque session de jeu, crash possible si l'observer fire après démontage de la vue
- **Cause** : `addObserver(forName:object:queue:using:)` (closure-based) mais `removeObserver(self, ...)` (incompatible — l'API closure renvoie un token qu'il faut conserver)
- **Fix** : stocker les tokens `NSObjectProtocol` retournés par `addObserver` et les passer à `removeObserver` ; `[weak self]` dans la closure

### BUG-002 — Timer fire après démontage
- **Fichier** : `LevelGameView.swift:607-614, 1355-1362`
- **Symptôme** : crash potentiel "Unexpectedly found nil" si l'utilisateur quitte au moment où le timer expire
- **Cause** : `Timer.scheduledTimer` capture `self` fortement, pas de garde `isGameSessionActive` dans la closure
- **Fix** : `[weak self]` + `guard let self, self.isGameSessionActive else { return }`

### BUG-003 — `asyncAfter` non annulables
- **Fichier** : `LevelGameView.swift:533-537`
- **Symptôme** : double appel possible à `startNewRound()`, score sauvegardé deux fois
- **Cause** : closures `DispatchQueue.main.asyncAfter` qui ne peuvent pas être annulées quand l'état change
- **Fix** : remplacer par `DispatchWorkItem` stockés dans un tableau et annulés sur `onDisappear` ou changement d'état

### BUG-004 — `globalScore` peut devenir négatif
- **Fichier** : `LevelSystemModels.swift:467-490`
- **Symptôme** : leaderboard peut afficher des scores négatifs (impossibles pour le joueur à battre)
- **Cause** : `addWrongAnswer()` et `addTimeout()` font `globalScore -= ...` sans clamp
- **Fix** : clamper `globalScore = max(0, globalScore - X)` côté `LevelRun`, OU clamper côté `LeaderboardStore.addScore()`

---

## 🟠 P1 — Logique visible

### BUG-008 — Refresh non-punitif L9-10 sans ré-annonce
- **Fichier** : `LevelGameView.swift:1168-1192`
- **Symptôme** : la grille se rafraîchit toutes les 1s, mais la couleur annoncée (audio) ne l'est pas → joueur perdu
- **Fix** : soit ré-annoncer la couleur via `SpeechService.speak(...)`, soit shuffle uniquement les positions sans changer les couleurs

### BUG-009 — Animation streak bonus trompeuse
- **Fichier** : `LevelSystemModels.swift:429-465`
- **Symptôme** : le "+20" affiché sur l'écran laisse croire que ces 20 points viennent **en plus**, alors qu'ils sont déjà dans `currentScore`
- **Fix** : clarifier l'animation (libellé "Streak !" au lieu de "+20") ou changer la séquence d'addition

### BUG-011 — Leaderboard non clampé ≥ 0
- **Fichier** : `LeaderboardStore.swift:60`
- **Symptôme** : conséquence de BUG-004 — scores négatifs persistent en leaderboard
- **Fix** : `addScore(max(0, score), ...)` ; couvert par BUG-004 si fix côté `LevelRun`

---

## 🟡 P2 — UX dégradée

### BUG-010 — "Back" actif pendant l'intro
- **Fichier** : `LevelGameView.swift:197-215`
- **Symptôme** : tap "Back" pendant les 3s d'intro → état UI bizarre
- **Fix** : `.disabled(showLevelIntro)` sur le bouton

### BUG-012 — Pas de gestion des interruptions audio
- **Fichier** : `SpeechService.swift:31-63`
- **Symptôme** : appel entrant casse l'audio, jeu ne ré-annonce pas la couleur après
- **Fix** : configurer `AVAudioSession` + listener `AVAudioSession.interruptionNotification`

### BUG-013 — `UIImpactFeedbackGenerator` recréé à chaque tap
- **Fichier** : `HapticsService.swift:17-29`
- **Symptôme** : haptics qui sautent en tap rapide
- **Fix** : garder une instance partagée + débounce 50ms

---

## 🔵 P3 — Tech debt avant ads/IAP

### BUG-000 — `GameView.swift` est mort
- **Fichier** : `ColorGame/GameView.swift` (1869 lignes)
- **Constat** : aucune référence externe (vérifié par grep), seul le `#Preview` final s'en sert
- **Fix** : supprimer le fichier + retirer du `project.pbxproj`

### BUG-014 — Reference cycles potentiels
- **Fichier** : `LevelGameView.swift` (général)
- **Constat** : à valider via Xcode Memory Graph après 15+ runs
- **Fix** : couvert par BUG-002 (`[weak self]` partout dans les timers/closures)

### BUG-015 — `try? JSONDecode` silencieux
- **Fichier** : `LeaderboardStore.swift:44-50`
- **Symptôme** : un JSON corrompu = leaderboard vidé sans warning
- **Fix** : log en cas d'erreur ; à durcir avant de stocker du state IAP

### BUG-016 — `buildValidGrid` sans timeout
- **Fichier** : `LevelGameView.swift:715-846`
- **Symptôme** : freeze 0,2-0,5s possible sur cas limites
- **Fix** : timeout 100ms + fallback de grille hard-codée

### BUG-018 — `CustomizationStore` : code mort
- **Fichier** : `CustomizationStore.swift:45-142`
- **Constat** : méthodes `updateEasyDuration`, etc. pour l'ancien système de modes — jamais appelées
- **Fix** : supprimer (~100 lignes)

### BUG-019 — Race sur double-tap "Retry"
- **Fichier** : `LevelSystemModels.swift:390-408`
- **Symptôme** : `resetLevelStats()` appelé 2× → `globalScore` incohérent
- **Fix** : flag `isResetInProgress` ou `.disabled` sur le bouton après tap

### BUG-020 — Pas de fallback si `currentLevelConfig == nil`
- **Fichier** : `LevelGameView.swift:1195-1218`
- **Symptôme** : edge case extrême → jeu freeze
- **Fix** : forcer `isLevelFailed = true` dans le guard

---

## Findings écartés

| ID | Raison |
|---|---|
| BUG-005 | Required scores ≠ MD : arbitré, code = source de vérité |
| BUG-006 | Wrong tap ne coûte pas de vie : arbitré, comportement code = voulu |
| BUG-007 | Progression points Color+Text : décision design, pas un bug |
| BUG-017 | `#if DEBUG` leak en prod : faux positif, stripé à la compilation |

---

## Plan d'attaque proposé

1. **Phase nettoyage** (low risk, gros gain de clarté)
   - BUG-000 : supprimer `GameView.swift`
   - BUG-018 : nettoyer `CustomizationStore`

2. **Phase mémoire & lifecycle** (le plus crucial pour App Store)
   - BUG-001 + BUG-002 + BUG-014 : pattern `[weak self]` + tokens d'observers, traités comme un bloc cohérent
   - BUG-003 : `DispatchWorkItem` annulables

3. **Phase scoring** (logique visible)
   - BUG-004 + BUG-011 : clamp `globalScore`/leaderboard à 0
   - BUG-009 : clarifier UX streak

4. **Phase finitions UX**
   - BUG-008, BUG-010, BUG-012, BUG-013

5. **Phase robustesse**
   - BUG-015, BUG-016, BUG-019, BUG-020

Chaque bug → une `change` OpenSpec individuelle (`/opsx:propose fix-bug-NNN`) avant fix.
