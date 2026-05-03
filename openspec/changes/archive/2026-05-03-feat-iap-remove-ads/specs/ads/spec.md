## ADDED Requirements

### Requirement: Interstitial is suppressed when the Remove Ads entitlement is held

`AdsService.showInterstitialIfReady(onDismiss:)` SHALL early-return (invoking `onDismiss()` immediately) when the player holds the Remove Ads entitlement (`StoreService.shared.hasRemoveAds == true`). The frequency counter SHALL NOT be incremented in that path, so a player whose entitlement later lapses does not see a backlog of "owed" ads.

#### Scenario: Entitled player at end of run

- **WHEN** an entitled player triggers any end-of-run event
- **THEN** no interstitial is presented, `onDismiss()` is invoked immediately, and the `runsSinceLastAd` counter is unchanged

#### Scenario: Entitlement loss reverts to ad gate

- **WHEN** an entitled player loses the entitlement (e.g., refund) mid-session
- **THEN** the next end-of-run event resumes the original frequency-cap behaviour, starting from whatever counter value the cap reset left
