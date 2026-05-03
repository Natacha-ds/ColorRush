## Context

The v1 ads layer ships interstitials behind a 1/3 frequency cap. The natural opt-out is a "Remove Ads" IAP. Tony has shipped exactly this pattern on another app **using RevenueCat**, so we keep the same stack here for consistency with his existing operations playbook.

**RevenueCat** is an IAP wrapper on top of StoreKit 2 that provides:
- Cross-platform abstraction (iOS / Android / web) — useful even for a single-platform app because it isolates business logic from Apple's churn.
- Server-side receipt validation, so client-side verification logic stays trivial.
- A unified entitlement model — the SDK lets us check `customerInfo.entitlements["remove_ads"]?.isActive`, period.
- Analytics, A/B test offering experiments, customer support tools.
- Free tier covers the price point of a casual indie game.

**Configuration.storekit** is a local JSON file that defines IAP products for development testing. Setting the scheme's `StoreKit Configuration` option to this file makes purchases simulate locally — RevenueCat respects the StoreKit Configuration and routes its own purchase APIs through it, so the same code path tests cleanly in the simulator.

## Goals / Non-Goals

**Goals:**
- Ship a Remove Ads IAP that integrates with the existing ads layer.
- Use RevenueCat throughout — no direct StoreKit 2 calls.
- Allow full client-side dev testing without App Store Connect via `Configuration.storekit`.
- Persist the entitlement so the gate works instantly on every launch (no cold-start ads served to a paying user).
- Provide a Restore Purchases flow as required by Apple.

**Non-Goals:**
- Multiple IAP products (only Remove Ads in v1; the `iap` capability is structured to extend later).
- Subscription products (Remove Ads is one-time / lifetime).
- Custom server-side validation. RevenueCat handles receipt validation via their service; that's enough for this scale.
- Promotion code redemption flow inside the app (handled by the App Store).
- Family Sharing semantics (Remove Ads will be auto-eligible since it's Non-Consumable; no extra UI surface needed).

## Decisions

### Use RevenueCat instead of native StoreKit 2

**Decision:** wrap IAP through RevenueCat's `Purchases` API rather than calling `Product.products(for:)` / `Product.purchase()` / `Transaction.currentEntitlements` directly.

**Rationale:** Tony's other shipping app uses RevenueCat. Keeping a single stack across his projects means: same dashboard, same analytics shape, same customer support tooling, same migration path if he ever ships a multi-platform version. The marginal cost (one SPM dependency, free pricing tier) is trivial compared to the operational consistency benefit. RevenueCat's docs and tooling are also better than vanilla StoreKit 2 for the surface we need (offerings, entitlements, customerInfo stream).

### `customerInfoStream` as continuous source of truth

**Decision:** in `StoreService.init()`, kick off three async tasks: load the offering's package, fetch the current `customerInfo`, and (long-running) iterate `Purchases.shared.customerInfoStream` to react to all subsequent updates (refunds, parental approvals, restores triggered elsewhere, etc.).

**Rationale:** the stream is RevenueCat's canonical reactive surface. Subscribing once at app launch means the entitlement state stays accurate without us writing manual refresh logic at strategic points.

### Cache the entitlement in `UserDefaults` for cold start

**Decision:** mirror the entitlement boolean in `UserDefaults` under `iap.removeAds.hasEntitlement`. Read it synchronously in `init()` before the network refresh resolves.

**Rationale:** RevenueCat's network round-trip on cold start can take 100-500 ms. We can't block the ad gate on it — a paying user opening the app should NOT see one ad before the gate kicks in. Cache provides instant access; the stream listener corrects any divergence within the second.

### Don't increment the ad frequency counter when entitled

**Decision:** in `AdsService.showInterstitialIfReady`, check the entitlement **before** incrementing `runsSinceLastAd`. If held, call `onDismiss()` directly and return — no counter mutation.

**Rationale:** if the user buys Remove Ads, plays 6 runs without ads, then somehow loses the entitlement (refund, lapsed Family Sharing seat), they shouldn't suddenly see 6 ads in a row. Treating the entitlement as a hard mute (not a "skip but track") is the correct semantics.

### `Configuration.storekit` location and scheme wiring

**Decision:** put the file at the project root (`Configuration.storekit`), parallel to `Info.plist`. Don't auto-wire it into the scheme — Tony manually configures the scheme's "StoreKit Configuration" once after this change is applied.

**Rationale:** scheme files (`*.xcscheme`) live inside `xcuserdata/` (per-user) and are not committed in this project. Setting the StoreKit Configuration there would only persist for one user. The file lives at the repo root so anyone who clones the project can set it up the same way locally.

### Restore button is always visible (when not entitled)

**Decision:** show the "Restore Purchases" link whenever the entitlement is NOT held — regardless of whether the user has ever attempted a purchase.

**Rationale:** Apple requires a Restore Purchases mechanism. Showing it conditionally based on past purchase attempts is fragile (we don't track that locally). Showing it whenever ads are still active is the simplest correct surface.

### Hardcode the public RevenueCat API key

**Decision:** hardcode `appl_qwmdfKXKKrZQWTQQofnvTIixBzJ` directly in `StoreService.swift`.

**Rationale:** RevenueCat's public iOS API key is *designed* to be in client code. It's not a secret — it identifies the app to RevenueCat's servers but doesn't grant any privileged operations. Apple's signed receipts are what actually authorize transactions; the RC public key just routes them to the right project.

## Risks / Trade-offs

- **[Risk]** A user could clear app data / delete-and-reinstall and lose the local entitlement cache. → **Mitigation:** RevenueCat's `customerInfo` re-resolves on every launch; the user's purchase persists at Apple's level and at RevenueCat's user-level. The cache is just for instant access on cold start; if it's stale, the next RC refresh fixes it within seconds.
- **[Risk]** A locally-defined StoreKit product (`Configuration.storekit`) accidentally ships in production if the scheme is misconfigured. → **Mitigation:** the file is dev-only; Apple's signed product takes precedence in Release. Document the scheme setup in the tasks list so Tony explicitly chooses "None" for production builds.
- **[Risk]** RevenueCat servers go down. → **Mitigation:** RC has been stable for ~6 years and has a status page; their SLA covers their service. Worst case during outage: cached entitlement remains accurate, new purchases fail. Acceptable for a casual indie app.
- **[Risk]** RevenueCat rebrands / acquires / changes pricing. → **Mitigation:** the wrapper they provide on top of StoreKit 2 means we can swap back to native StoreKit 2 in a few hundred lines if ever needed. Migration cost is bounded.
- **[Trade-off]** One more SPM dependency (~5 MB binary). Acceptable for the operational consistency benefit.

## Migration Plan

No runtime migration. The `iap.removeAds.hasEntitlement` key starts unset → `false` for everyone, which matches the pre-change behaviour (everyone sees ads). Once a player buys Remove Ads, the key flips true and persists.

**Rollback:** `git revert` the implementation commit. The Home button disappears, the AdsService gate vanishes (so any past purchaser would temporarily see ads again, but their App Store + RevenueCat entitlement is preserved). Re-applying the change later restores the gate; entitlements re-resolve on launch from RevenueCat's `customerInfo`.
