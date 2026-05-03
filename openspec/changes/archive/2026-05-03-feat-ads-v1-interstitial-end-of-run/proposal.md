## Why

Ads are the first monetisation lever for ColorRush. The product call (confirmed with the user) is a single interstitial format at end-of-run with a 1-in-3 frequency cap — a casual-game baseline that respects flow during gameplay and the natural breakpoint between sessions. AdMob entries are already created (App ID `ca-app-pub-9259578521352937~8432033718`, Interstitial Ad Unit ID `ca-app-pub-9259578521352937/6262225438`), and the user has prior shipping experience with AdMob+IAP on another app.

Thanks to BUG-022, every "end of run" code path now flows through a small set of normalised callbacks (in-game Back chevron, LevelFailedView Back, LevelCompleteView Back, LevelGameOverView Back, FinalWinView play-harder / see-leaderboard). This is the right place to slot the ad-presentation hook: one helper, five call sites, deterministic UX.

## What Changes

- Introduce a new `ads` capability covering everything ad-related (this v1 plus the future rewarded "extra life" workstream).
- Add the **Google Mobile Ads SDK** as a Swift Package Manager dependency (manual step in Xcode UI).
- Add Info.plist entries: `GADApplicationIdentifier`, `SKAdNetworkItems`.
- Add an `AdsService` singleton (`@MainActor` `ObservableObject`) responsible for SDK init, UMP consent flow, interstitial pre-load, frequency-capped presentation, and post-dismissal callback.
- Wire `AdsService.shared.showInterstitialIfReady(from:onDismiss:)` into every end-of-run callback. The `onDismiss` closure posts the existing `DismissToHome` notification, so the navigation cascade we shipped for BUG-022 is preserved.
- Use Google's **test interstitial ad unit ID** in DEBUG builds, the real production ID in Release builds, to keep AdMob policy compliance during development.
- Initialize `AdsService` from `ColorGameApp` after UMP consent resolves.

## Capabilities

### New Capabilities

- `ads`: covers ad SDK initialisation, consent management, ad presentation, and frequency policy. Future ad workstreams (rewarded extra-life, eventual banner / app-open formats if added) extend this capability.

### Modified Capabilities

None. The existing `level-gameplay` capability is unchanged in spec terms — the end-of-run flow simply gains an optional ad-presentation hook between save-and-reset and the dismiss cascade.

## Impact

- **Code**: ~150 lines net. New file `ColorGame/AdsService.swift` (~120 lines), small wiring updates in `LevelGameView.swift` (5 call sites), small init hook in `ColorGameApp.swift`, and Info.plist entries.
- **Build**: a new SPM dependency (`googleads/swift-package-manager-google-mobile-ads`) increases the binary size by ~10–15 MB (typical for Mobile Ads SDK). Build green required after the SDK is added.
- **Runtime**:
  - Mobile Ads SDK initializes once at app launch after UMP consent resolves.
  - First interstitial pre-loads in the background; subsequent ones reload after each presentation.
  - End-of-run flow becomes: save score → maybe show interstitial → on dismiss, post `DismissToHome` → cascade to Home tab.
- **Privacy**: the SDK ships its own privacy manifest. We add `GADApplicationIdentifier` and `SKAdNetworkItems` to the app's Info.plist as required by the SDK.
- **Tests**: no tests exist today.
- **Migration**: none.
