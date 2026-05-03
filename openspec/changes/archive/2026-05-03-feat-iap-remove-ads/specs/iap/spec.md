## ADDED Requirements

### Requirement: Remove Ads is a non-consumable IAP product

ColorRush SHALL offer a single In-App Purchase product, "Remove Ads", with product ID `tonic.colorrush.removeads`, configured as **Non-Consumable** (one-time purchase, lifetime entitlement). The product SHALL be loaded once per app launch via RevenueCat's `Purchases.shared.offerings()` API, taking the package from the offering currently marked as "current" in the RevenueCat dashboard.

#### Scenario: Package loads on launch

- **WHEN** the app finishes launching with a network connection and RevenueCat is configured
- **THEN** `StoreService.shared.package` is non-nil and contains the localised price string accessible via `package.storeProduct.localizedPriceString`

### Requirement: Purchase flow grants the entitlement

When the player initiates a purchase from the UI, the app SHALL call `Purchases.shared.purchase(package:)` and, on a non-cancelled result, persist the Remove Ads entitlement and update the UI accordingly.

#### Scenario: Successful purchase

- **WHEN** the player taps the Remove Ads button and confirms the purchase in Apple's sheet
- **THEN** `StoreService.shared.hasRemoveAds` becomes `true`, the value is persisted to `UserDefaults` under the key `iap.removeAds.hasEntitlement`, and the Home button is hidden

#### Scenario: User cancels purchase

- **WHEN** the player taps the Remove Ads button but cancels in Apple's sheet
- **THEN** `hasRemoveAds` remains `false`, no UserDefaults change, and the Home button stays visible for retry

### Requirement: Restore Purchases recovers the entitlement on a new device or reinstall

The app SHALL expose a "Restore Purchases" action that calls `Purchases.shared.restorePurchases()` and re-checks the entitlement. If the user has previously purchased Remove Ads on the same Apple ID, the entitlement SHALL be restored.

#### Scenario: Restore on a fresh install

- **WHEN** the player reinstalls ColorRush on the same Apple ID and taps "Restore Purchases"
- **THEN** the Remove Ads entitlement is restored without a second charge, and the UI updates to the entitled state

### Requirement: Cached entitlement gates ads instantly on launch

The `hasRemoveAds` boolean SHALL be persisted in `UserDefaults` so that the ad gate works correctly on every cold launch, before the asynchronous RevenueCat `customerInfo` refresh completes.

#### Scenario: Cold launch with prior purchase

- **WHEN** a previously-entitled user launches the app
- **THEN** `hasRemoveAds` is read from `UserDefaults` synchronously and ads are suppressed before any end-of-run event in the new session

#### Scenario: Cached state diverges from server truth

- **WHEN** the user gets a refund and the cached value is still `true`
- **THEN** `Purchases.shared.customerInfoStream` (subscribed at launch and continuously) emits a refreshed `customerInfo` whose `entitlements["remove_ads"]?.isActive == false`, and `StoreService` updates the cache accordingly; ads resume on the next end-of-run event after the refresh

### Requirement: customerInfoStream observed continuously

The app SHALL subscribe to `Purchases.shared.customerInfoStream` for the lifetime of the process and SHALL refresh the entitlement state on every emission.

#### Scenario: A pending transaction completes asynchronously (e.g., parental approval)

- **WHEN** the player triggers a purchase that requires parental approval and the parent later approves it from another device
- **THEN** the in-app `customerInfoStream` listener receives the updated `customerInfo`, updates the entitlement state, and the UI flips to entitled without requiring another in-app action
