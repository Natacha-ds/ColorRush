## Context

ColorRush ships no ads today. The end-of-run flow lives in five callbacks, all wired through `LevelGameView.swift` after the BUG-022 normalisation:

1. In-game Back chevron (mid-level voluntary exit)
2. `LevelFailedView.onBackToHome` (failed level, voluntary exit)
3. `LevelCompleteView.onBackToHome` (mid-run voluntary exit after completing a level)
4. `LevelGameOverView.onBackToHome` (out of lives)
5. `FinalWinView.onPlayHarder` and `.onSeeLeaderboard` (won level 10)

All five paths today: save score → reset run state → post `DismissToHome` notification → cascade dismiss back to Home tab.

The ad-presentation hook plugs in between "reset run state" and "post DismissToHome": frequency-cap permitting, present the interstitial; the `DismissToHome` notification fires from the dismissal callback so the cascade still happens after the ad UX completes.

## Goals / Non-Goals

**Goals:**
- Ship a v1 ads layer with the smallest reasonable footprint (one format, one trigger, one frequency policy).
- Keep the existing end-of-run UX intact when the cap blocks the ad or when the ad fails to load.
- Use test ad units in DEBUG so dev / sim work doesn't impact AdMob policy.
- Make the consent flow (UMP) explicit and resolved before any ad is requested.

**Non-Goals:**
- Banner ads, App Open ads, native ads. Out of scope for v1.
- Rewarded ads (the "extra life on game over" workstream is tracked separately for post-v1).
- Personalised ads / ATT (App Tracking Transparency) prompt — start with non-personalised to avoid the iOS-level prompt; the UMP consent form covers the privacy disclosures.
- A/B testing ad cadence — fixed 1-in-3 cap for v1; revisit with telemetry.

## Decisions

### One singleton `AdsService` instead of per-view ad logic

**Decision:** introduce a `@MainActor` `ObservableObject` singleton `AdsService` that owns the Mobile Ads SDK lifecycle (init, consent, pre-load, present, reload, frequency counter).

**Rationale:** the five end-of-run call sites should be one-liners (`AdsService.shared.showInterstitialIfReady(...)`); the actual ad mechanics are stateful and deserve a dedicated owner. `@MainActor` because the Mobile Ads SDK requires main-thread presentation. Singleton because one app instance has at most one pre-loaded interstitial at a time. `ObservableObject` so that future SwiftUI surfaces (e.g., a "Watch ad to revive" UI in the rewarded workstream) can `@StateObject` it.

### Frequency cap: 1-in-3, counter-based, runtime-only

**Decision:** keep an in-memory `runsSinceLastAd: Int` counter and a `frequency = 3` constant. Increment on every `showInterstitialIfReady` call; present only if the counter has reached `frequency`; reset to 0 on present.

**Rationale:** the simplest mechanism that achieves the product intent. No persistence — the counter resets on app launch, which is acceptable for a casual app where players come back fresh. AdMob's own dashboard frequency caps exist but layering them with our own keeps the ad-show logic self-contained and testable.

### Test ad units in DEBUG, real ones in Release

**Decision:** wrap the interstitial ad unit ID in `#if DEBUG` to use Google's published test ID (`ca-app-pub-3940256099942544/4411468910`) in dev builds and Tony's real ID (`ca-app-pub-9259578521352937/6262225438`) in Release.

**Rationale:** AdMob's policies prohibit testing against real ad units (you can lose your account for self-clicks or repeated test impressions). Google's test units serve canonical creatives that always load and never count toward billing. Standard pattern for AdMob iOS integration.

### UMP consent flow runs before SDK init

**Decision:** in `ColorGameApp` (or via a delegate adapter), call the UMP consent flow first; initialize Mobile Ads only inside the UMP completion handler.

**Rationale:** required for GDPR (and increasingly other jurisdictions). Initializing Mobile Ads before consent has resolved can produce non-compliant ad requests. Google's docs lay out this exact ordering. Also use `UMPDebugSettings.geography = .EEA` in DEBUG to force the consent form during development.

### `onDismiss` callback rather than the ad delegate as the navigation trigger

**Decision:** `showInterstitialIfReady(from:onDismiss:)` always invokes `onDismiss` — either after the ad's `FullScreenContentDelegate.adDidDismissFullScreenContent` fires, or immediately if the cap blocked the ad or the ad failed to load.

**Rationale:** keeps the call-site code simple — the closure is "after this, post `DismissToHome`". The caller doesn't need to know whether the ad ran or not. `AdsService` handles the branching internally.

### SDK addition done in Xcode UI, not via pbxproj edits

**Decision:** the Swift Package Manager dependency is added by Tony manually via Xcode's "Add Package Dependencies" UI, not via me editing `project.pbxproj`.

**Rationale:** SPM in pbxproj involves opaque UUIDs, framework search paths, package resolution data, and a `Package.resolved` file. Editing these by hand is fragile and error-prone. Xcode's UI does it correctly in one click. The tasks file documents this as a manual step so the apply phase pauses.

## Risks / Trade-offs

- **[Risk]** UMP consent form presentation requires a `UIViewController`, but ColorRush is SwiftUI-first. → **Mitigation:** use `UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.keyWindow?.rootViewController`. Standard SwiftUI-to-UIKit bridge for ad presentation.
- **[Risk]** Pre-loading an interstitial holds a network connection / memory until presented. If the player never finishes a run, the ad sits idle. → **Mitigation:** acceptable. Mobile Ads SDK auto-expires ads (~1 hour). On expiry, the next presentation attempt fails silently and triggers a reload.
- **[Risk]** The Mobile Ads SDK adds 10–15 MB to the binary. → **Mitigation:** acceptable for a real product. App Store size limits are far higher.
- **[Risk]** Real ad creatives could occasionally hit edge cases (orientation, audio overlap with our `SpeechService`). → **Mitigation:** Google's SDK manages audio session interruption itself; our `pauseTimer` flow (BUG-001) already handles app-level audio interruptions cleanly. Validate empirically in the simulator after wiring.
- **[Trade-off]** Showing an ad as part of the "exit run" flow extends the perceived exit time. → Accepted because (a) interstitials are the standard ad format for casual games, (b) the 1-in-3 cap keeps it tolerable, (c) Tony will ship a "Remove Ads" IAP later for users who want to opt out.

## Migration Plan

No runtime migration. The existing run flow keeps working when:
- The SDK is not yet initialised (early launch).
- UMP consent is pending.
- The frequency cap blocks the ad.
- The ad fails to load.
- The ad fails to present.

In all those cases, `onDismiss` fires immediately and the existing `DismissToHome` cascade runs as today.

**Rollback:** `git revert` the implementation commit. Remove the SPM package dependency in Xcode (manual). The end-of-run flow reverts to the BUG-022 behaviour (no ad attempt). No persisted state to clean up.
