## Why

The v1 ads workstream (interstitial at end-of-run, 1/3 frequency cap) creates a natural "Remove Ads" IAP opportunity — the standard casual-game monetisation pairing. Players who don't want ads get a one-time, lifetime opt-out; the app earns directly without giving up the ad-funded majority.

Confirmed product call:
- Non-Consumable IAP, Product ID `tonic.colorrush.removeads`
- €2,99 (Apple's price tier matching that EUR amount, auto-localised in other markets)
- Discreet button on the Home screen + a "Restore Purchases" link as required by Apple

## What Changes

- Introduce a new `iap` capability covering In-App Purchases. v1 has a single product ("Remove Ads"); future products extend the same capability.
- Add **RevenueCat** as the IAP wrapper (Tony already uses RevenueCat on another shipping app, so we keep stack consistency). RevenueCat sits on top of StoreKit 2 and provides cross-platform receipt validation, analytics, A/B testing, and a unified entitlement model. Free tier covers indie revenue.
- Add `StoreService` (`@MainActor` `ObservableObject` singleton) wrapping `Purchases.shared` to load the current offering's package, drive purchase / restore flows, listen to RevenueCat's `customerInfoStream`, and persist the entitlement state.
- Add a local **`Configuration.storekit`** file so we can develop/test purchases on the simulator. RevenueCat respects the StoreKit Configuration in the scheme for product fetching and purchase simulation during dev.
- Modify `AdsService.showInterstitialIfReady(onDismiss:)` to early-return (with `onDismiss()` invoked immediately) when the Remove Ads entitlement is held. The frequency counter is **not** incremented in that case, so purchasers don't accumulate "ads owed" if they ever lose the entitlement.
- Add UI on `HomeView`: a "✨ Remove Ads — €X" capsule button (white background, gradient stroke matching the Best Score pill) and a "Restore Purchases" link, both auto-hide once the entitlement is held.
- `ColorGameApp.init()` instantiates `StoreService.shared` so RevenueCat configures and the entitlement state resolves at app launch.

## Capabilities

### New Capabilities

- `iap`: covers In-App Purchases — RevenueCat configuration, package loading, purchase flow, restore, customerInfo stream listening, and entitlement persistence. v1 ships the Remove Ads product; the capability is forward-compatible with future SKUs.

### Modified Capabilities

- `ads`: the existing requirement that "an interstitial ad is considered for presentation at every end-of-run event" gains an exception — when the Remove Ads entitlement is held, the call is a no-op.

## Impact

- **Code**: ~120 lines in `StoreService.swift` (RevenueCat-based), ~70 lines of UI in `HomeView`, a small gate in `AdsService`, and an `init()` line in `ColorGameApp`. Plus `Configuration.storekit` (~50 lines of JSON).
- **Build**: SPM dependency `https://github.com/RevenueCat/purchases-ios-spm` adds ~5 MB to the binary. Build green required.
- **Runtime / player behavior**:
  - Home screen gains a "✨ Remove Ads — €2,99" button and a "Restore Purchases" link below the Play CTA.
  - Purchase flow: tap → RevenueCat → Apple's sheet → entitlement granted → button hides, ads stop firing.
  - Restore flow: works across reinstalls and across multiple devices on the same Apple ID via RevenueCat's anonymous user mapping.
- **Persistence**: `UserDefaults` cache for the entitlement so the gate works instantly at launch; RevenueCat's `customerInfo` is the source of truth and refreshes the cache asynchronously.
- **External dependencies**: RevenueCat SDK via SPM. RevenueCat's free tier covers indie-scale revenue (€2.5k/month MRR) with no per-transaction fee.
- **Tests**: no automated tests (none exist today). Manual coverage in the Tasks section.
- **Production ship dependency**: Tony creates the App Store Connect entry + IAP product + RevenueCat dashboard config (project, entitlement, offering). With those done, no code changes are required to flip from dev-test to production.
