## Context

`AdsService.swift` currently owns the interstitial path: UMP consent at bootstrap, `MobileAds.shared.start`, preload via `InterstitialAd.load`, frequency-capped presentation via `showInterstitialIfReady`, and a `FullScreenContentDelegate` that re-preloads after each dismissal. The new rewarded surface re-uses all of this scaffolding (consent, SDK start, delegate cleanup) but sits on a parallel ad-unit + preload + present path.

`LevelGameOverView` (in `LevelGameView.swift`) already renders when `failedReason == .maxMistakes`. The player's only current escape is the "Back to Home" button, which routes through `AdsService.shared.showInterstitialIfReady` and the `DismissToHome` notification cascade.

Lives are accounted in `LevelRun` via:
- `livesLost: Int` (cumulative this run)
- `mistakeTolerance.totalLives` (cap by difficulty: Easy=5, Normal=3, Hard=1)
- `remainingLives` (computed: `max(0, totalLives - livesLost)`)
- `isGameOver` (computed: `remainingLives <= 0`)
- `loseLife()` increments `livesLost`

The rewarded grant is the symmetric inverse: `livesLost -= 1` (guarded so it never goes negative).

## Goals / Non-Goals

**Goals:**
- Add a rewarded-ad path in `AdsService` symmetric to the interstitial one, with its own preload state and presentation API.
- Provide an in-run revive on `LevelGameOverView` only (the screen for max-mistake game-over) — gated by a one-shot per-run flag on `LevelRun`.
- Honor the Remove Ads entitlement: entitled players get the revive **for free** (no ad), preserving the IAP value proposition.
- Make skipping the ad equivalent to using the revive (one-shot regardless of completion) — anti-abuse.
- Keep all existing interstitial behavior unchanged.

**Non-Goals:**
- Multiple revives per run, or refilling the revive flag mid-run.
- Rewarded ads on `LevelFailedView` (the insufficient-score screen) — extra lives don't help on score failures.
- A "free retry without watching" surface — players who don't want to watch the ad just tap Back to Home as before.
- Giving entitled players a button label that hides the fact that they got a perk (the "✨ Continue (free)" label is explicit).
- Animating the revive granting (a simple dismissal of the game-over view + the next-level transition is enough).

## Decisions

### One rewarded ad unit, separate state from the interstitial

**Decision:** add a parallel `rewardedAdUnitID` constant (DEBUG = Google's test rewarded ID, Release = a new production ad unit Tony creates), a parallel `@Published private(set) var rewardedReady: Bool`, and a parallel `private var rewardedAd: RewardedAd?`. Preloading is its own async method `preloadRewardedAd()`, called once at bootstrap (after UMP consent + `MobileAds.shared.start`) and again after each successful presentation in the delegate path.

**Rationale:** the GMA SDK draws separate inventory for rewarded vs interstitial — collapsing them under a single `currentAd` would lose the ability to preload both ahead of time and would force serial loading. Independent state means the rewarded button can be enabled the instant the rewarded preload finishes, regardless of interstitial state.

**Alternative considered:** a single `currentAd` of an erased type. Rejected — the `present(from:userDidEarnRewardHandler:)` call exists only on `RewardedAd`, and the interstitial has no reward closure. Erasing would just push the type discrimination one level deeper without simplifying anything.

### `showRewardedAdIfReady(onReward:onSkip:)` API

**Decision:** the API takes two callbacks. `onReward` runs **only** when the SDK confirms a reward was earned (the user actually watched the ad to completion). `onSkip` runs in three cases: (a) the ad was not loaded, (b) no host VC was available to present it, (c) the user dismissed the ad before earning the reward.

**Rationale:** the UI needs to differentiate "life granted" from "no life granted" so it can choose the right next state. Having both callbacks at the API boundary keeps the gameplay code readable: `onReward = { grantExtraLife(); resumeRun() }`, `onSkip = { /* leave player on game-over view */ }`. The Remove Ads short-circuit invokes `onReward` immediately so the call site doesn't need to branch on entitlement.

**Alternative considered:** a single `(Bool) -> Void` callback. Rejected — naming the two paths separately is clearer for the SwiftUI view code and makes the spec cleaner to read.

### One-shot per run regardless of skip

**Decision:** `LevelRun.hasUsedRewardedRevive` is set to `true` the moment the rewarded button is **tapped**, before the ad presents. If the user closes the ad early, the flag stays `true` and they cannot try again in the same run.

**Rationale:** allowing infinite retries on skip would let users farm impressions or game the cap. One-shot regardless removes the temptation. The cost is a single edge case where the user accidentally taps Continue then panics and closes — they lose the revive. Acceptable; the UI has a clear "Watch Ad" label.

**Alternative considered:** flip the flag only on reward earned, not on tap. Rejected per anti-abuse reasoning above.

### Remove Ads holders bypass the ad but still see the button

**Decision:** entitled players see the "Continue (free)" button (different label, no ad shown). Tapping invokes `onReward` immediately, granting the life. The flag `hasUsedRewardedRevive` still flips, so the one-shot rule still applies — entitled players also get **one** revive per run.

**Rationale:** keeping the per-run cap consistent across entitled / non-entitled players keeps the game balance the same. The only thing the entitlement changes is whether you watch an ad to claim it. If we let entitled players revive infinitely, we'd be giving them a strictly easier game, not just an ad-free one — that's beyond what "Remove Ads" promises.

**Alternative considered:** hide the button entirely for entitled players. Rejected — the revive is a gameplay feature that all players should access; only the friction (the ad) differs.

### `LevelGameOverView` button placement and styling

**Decision:** render the rewarded button **above** the existing "Back to Home" button on `LevelGameOverView`. Style it as a capsule with a gradient stroke (orange → pink) to visually differentiate it from the existing blue/purple capsules used for "Global Ranking" and "Remove Ads". Disabled (opacity 0.5) until `AdsService.shared.rewardedReady`.

**Rationale:** the player's eye lands on the game-over panel; placing the revive above the "Back to Home" mirrors the F-pattern reading order — the "more attractive" option comes first, the "give up" option second. The orange/pink palette also reads as "energy / urgency", suiting the second-chance moment. Keeping it disabled before preload prevents tap-and-wait dead time.

## Risks / Trade-offs

- **[Risk]** Player taps Continue, watches a long ad (~30s), and the round timer / level state is stale on return. → **Mitigation:** the ad is presented while `LevelGameOverView` is showing, which is *outside* gameplay (`isGameSessionActive == false`). Game timers are already invalidated. On reward, `grantExtraLife()` then `startNewLevel()` rebuilds the level fresh — no stale state.
- **[Risk]** Player accidentally taps Continue and panics, losing their revive. → **Mitigation:** clear button label "Continue — Watch Ad" makes the consequence explicit. Acceptable per anti-abuse decision.
- **[Risk]** AdMob rewarded fill rate is much lower than interstitial in some regions, leading to disabled buttons even mid-session. → **Mitigation:** `rewardedReady` is published, so the button reflects load state. If the ad never loads, the player still has "Back to Home" available — the revive is a bonus, not a requirement.
- **[Risk]** New production rewarded unit takes 24-48h to start serving. → **Mitigation:** mention in Tasks. DEBUG builds use Google's test rewarded ID and serve immediately. TestFlight will see the production unit; first impressions land after warm-up.
- **[Risk]** Two preload paths (interstitial + rewarded) competing for SDK init. → **Mitigation:** the GMA SDK supports concurrent loads of different formats. Both run as separate `Task`s after `MobileAds.shared.start`. No coordination logic needed.
- **[Trade-off]** A second ad unit doubles AdMob console maintenance (eCPM tuning, mediation, etc.). → Acceptable for the new revenue surface and improved retention metric.

## Migration Plan

No runtime migration. Existing players who upgrade simply gain access to the new revive button on their next game-over. No persistence changes.

**Rollback:** `git revert` the implementation commit. The rewarded button vanishes; the rest of the ads stack is unaffected. The new AdMob ad unit can stay defined in the AdMob console (it just goes idle).
