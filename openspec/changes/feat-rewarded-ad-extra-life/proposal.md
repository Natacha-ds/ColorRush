## Why

The v1 monetization stack ships interstitials (every 3 levels played) and a Remove Ads IAP. The natural complementary surface is a **rewarded ad** that gives the player an opt-in second chance — watch a short ad in exchange for one extra life when they hit game-over. This deepens the monetization without degrading core UX (the player chooses to engage), and the new revive moment also rescues the run that would otherwise end frustratingly.

Tracked in user memory as the "Rewarded ad — extra life" backlog item, post-v1.

## What Changes

- Extend the `ads` capability with a **rewarded** ad variant alongside the existing interstitial. The two ad surfaces share `AdsService`, the UMP consent flow, and the lifecycle delegate, but use independent ad units, independent preload state, and independent presentation paths.
- Introduce a one-time, in-run revive opportunity on the `LevelGameOverView` (the screen rendered when `failedReason == .maxMistakes`). When the player taps **"🎬 Continue — Watch Ad"**, the rewarded ad is presented; on reward earned, one life is restored and the run resumes at the same level.
- Cap the revive to **once per run**: a new flag `LevelRun.hasUsedRewardedRevive` is set on success and resets only on `startRun(...)` / `resetRunStats()`. After use, the button hides for the remainder of the run regardless of further game-over events.
- For **Remove Ads holders**: the same button appears (labeled "✨ Continue (free)") and the life is granted immediately without playing an ad — honoring the IAP promise of "no ads" while still letting paying players enjoy the revive feature.
- The "skip" path (player closes the rewarded ad before earning the reward) is treated as **anti-abuse one-shot**: even a skip burns the per-run revive opportunity, preventing loop-watch attempts.
- Add a new production AdMob ad unit ID for the rewarded format (Tony creates manually in the AdMob console). Test ad unit in DEBUG uses Google's documented test rewarded ID `ca-app-pub-3940256099942544/1712485313`.

## Capabilities

### New Capabilities

_(none — extends existing `ads` capability)_

### Modified Capabilities

- `ads`: gains a rewarded-ad surface in `AdsService` (preload, presentation, reward callback, skip callback) and a UI hook on `LevelGameOverView`. Existing interstitial requirements are unchanged.

## Impact

- **Code**: ~80 lines in `AdsService.swift` (rewarded preload, present method, delegate paths), ~10 lines in `LevelSystemModels.swift` (`hasUsedRewardedRevive` flag, `grantExtraLife()` method), ~50 lines in `LevelGameOverView` (button + tap handler + entitlement-aware label).
- **Build**: no new SPM dependency — `RewardedAd` ships with the existing `GoogleMobileAds` framework.
- **Runtime / player behavior**:
  - On game-over (out of lives), an additional capsule "🎬 Continue — Watch Ad" appears above "Back to Home". It is disabled until the rewarded ad has finished preloading.
  - Tap → ad plays → reward earned → +1 life → run resumes on the same level. Skip the ad → no life granted, button still hidden for the rest of the run (anti-abuse).
  - Remove Ads holders see "✨ Continue (free)" and skip the ad entirely.
- **Persistence**: nothing new — `hasUsedRewardedRevive` is in-memory per `LevelRun` and resets with each new run, no `UserDefaults`.
- **External dependencies**: AdMob — Tony creates one new Rewarded ad unit and pastes its ID into `AdsService.swift`. The same `GADApplicationIdentifier` in `Info.plist` covers both interstitial and rewarded.
- **Tests**: no automated tests (none exist today). Manual coverage in the Tasks section, including DEBUG flows with Google's test rewarded ad and a regression check that interstitial behavior is unchanged.
- **Production ship dependency**: Tony's new rewarded ad unit will go through AdMob's standard 24-48h serving warm-up before real ads land in TestFlight/production.
