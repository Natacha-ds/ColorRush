## 1. Manual setup (Tony)

- [x] 1.1 In **App Store Connect**, app entry exists for Bundle ID `tonic.colorrush` (display name: "ColorRush - Tap the color")
- [x] 1.2 In App Store Connect → Features → In-App Purchases, the product `tonic.colorrush.removeads` exists (Non-Consumable, €2,99). Status may be "Missing Metadata" until full submission; OK for dev testing
- [x] 1.3 **RevenueCat dashboard**: project for ColorRush created, App Store Connect linked via In-App Purchase Key, public iOS SDK key obtained (`appl_qwmdfKXKKrZQWTQQofnvTIixBzJ`)
- [x] 1.4 **RevenueCat — Product**: `tonic.colorrush.removeads` imported
- [x] 1.5 **RevenueCat — Entitlement**: `remove_ads` created, product attached
- [x] 1.6 **RevenueCat — Offering**: `default` (current), with a Lifetime package pointing at the product
- [x] 1.7 **Xcode — SPM**: `https://github.com/RevenueCat/purchases-ios-spm` added; `RevenueCat` lib linked to the `ColorGame` target

## 2. Local StoreKit Configuration

- [x] 2.1 Created `Configuration.storekit` at the project root with the `tonic.colorrush.removeads` Non-Consumable product (price 2.99, EN + FR localisations)
- [x] 2.2 Scheme wiring done by Tony (Edit Scheme → Run → Options → StoreKit Configuration → `Configuration.storekit`)

## 3. StoreService implementation

- [x] 3.1 Created `ColorGame/StoreService.swift` with `import Combine, Foundation, RevenueCat`
- [x] 3.2 `@MainActor final class StoreService: ObservableObject` shared singleton
- [x] 3.3 Constants: `apiKey = "appl_qwmdfKXKKrZQWTQQofnvTIixBzJ"`, `entitlementID = "remove_ads"`, `entitlementCacheKey = "iap.removeAds.hasEntitlement"`
- [x] 3.4 `@Published private(set) var package: Package?` for the current offering's purchasable
- [x] 3.5 `@Published private(set) var hasRemoveAds: Bool` initialised from the UserDefaults cache for instant cold-start access
- [x] 3.6 `customerInfoTask` cancelled on deinit
- [x] 3.7 `init()` configures `Purchases` with the API key, then kicks off `loadOfferings()`, `refreshEntitlement()`, and the `customerInfoStream` listener
- [x] 3.8 `loadOfferings()` uses `Purchases.shared.offerings()` and prefers `current?.lifetime`, falls back to `current?.availablePackages.first`
- [x] 3.9 `refreshEntitlement()` fetches `customerInfo()` and routes through `handle(_:)`
- [x] 3.10 `purchase()` calls `Purchases.shared.purchase(package:)`, returns `false` on cancel, otherwise updates the entitlement and returns the new active state
- [x] 3.11 `restore()` calls `Purchases.shared.restorePurchases()` and routes through `handle(_:)`
- [x] 3.12 `customerInfoStream` listener iterates the AsyncStream and updates the entitlement on every emission

## 4. AdsService gate

- [x] 4.1 `AdsService.showInterstitialIfReady` checks `StoreService.shared.hasRemoveAds` BEFORE incrementing the counter and early-returns with `onDismiss()` if entitled

## 5. App-level wiring

- [x] 5.1 `ColorGameApp.init()` references `_ = StoreService.shared` so the singleton's lazy init kicks off RevenueCat configuration + offerings load + entitlement refresh at app launch

## 6. HomeView UI

- [x] 6.1 Added `@StateObject private var store = StoreService.shared` plus `@State private var isPurchasing` and `@State private var isRestoring`
- [x] 6.2 Below the Play CTA, a primary capsule button "✨ Remove Ads — €X" rendered when `!store.hasRemoveAds`. White background, gradient stroke (purple → pink), gradient text, soft shadow. Disabled / opacity 0.6 while `package == nil`
- [x] 6.3 A "Restore Purchases" secondary link below the primary button
- [x] 6.4 Loading state via `ProgressView` while `isPurchasing` or `isRestoring`
- [x] 6.5 Title uses `package.storeProduct.localizedPriceString` so the displayed price matches whatever RevenueCat / Apple returns

## 7. Validation

- [x] 7.1 `xcodebuild ... build` returns `BUILD SUCCEEDED`
- [x] 7.2 Simulator (with `Configuration.storekit` selected): home shows "✨ Remove Ads — €2,99" + "Restore Purchases"
- [x] 7.3 Simulator (purchase): tap → simulated checkout → tap Buy → button disappears in real-time (via `customerInfoStream` propagation). Force-quit and relaunch → entitlement persists, button stays hidden
- [x] 7.4 Simulator (regression): without the entitlement, the existing 1/3 frequency cap behaviour still works (the `AdsService` gate is bypassed for entitled users only)

## 8. Commit & archive

- [x] 8.1 Commit with message `feat: ship Remove Ads IAP via RevenueCat (feat-iap-remove-ads)`
- [x] 8.2 No `AUDIT_BUGS.md` entry — feature
- [x] 8.3 Archive via `/opsx:archive feat-iap-remove-ads`
