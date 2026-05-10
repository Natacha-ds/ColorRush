import Combine
import GoogleMobileAds
import SwiftUI
import UIKit
import UserMessagingPlatform

@MainActor
final class AdsService: NSObject, ObservableObject {
  static let shared = AdsService()

  // MARK: - Configuration

  #if DEBUG
    // Google's documented test interstitial ID — always serves a test creative,
    // safe to use during development without impacting AdMob policy.
    private let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    // Google's documented test rewarded ID — same guarantee.
    private let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
  #else
    private let interstitialAdUnitID = "ca-app-pub-9259578521352937/6262225438"
    private let rewardedAdUnitID = "ca-app-pub-9259578521352937/2792777342"
  #endif

  /// Show an interstitial at most once every `frequency` levels played
  /// (a level "played" = the player either completed it or failed it).
  private let frequency: Int = 3

  // MARK: - State

  @Published private(set) var isReady: Bool = false
  @Published private(set) var rewardedReady: Bool = false

  private var interstitial: InterstitialAd?
  private var levelsSinceLastAd: Int = 0
  private var pendingDismissCallback: (() -> Void)?

  private var rewardedAd: RewardedAd?
  private var pendingRewardedReward: (() -> Void)?
  private var pendingRewardedSkip: (() -> Void)?

  override private init() {
    super.init()
  }

  // MARK: - Lifecycle

  /// Kick off the UMP consent flow and, once resolved, start the Mobile Ads
  /// SDK and preload the first interstitial. Safe to call once at app launch.
  func bootstrap() {
    let parameters = RequestParameters()

    #if DEBUG
      // Force the EU consent form to appear in the simulator for testing.
      let debug = DebugSettings()
      debug.geography = .EEA
      parameters.debugSettings = debug
    #endif

    ConsentInformation.shared
      .requestConsentInfoUpdate(with: parameters) { [weak self] error in
        if let error {
          print("UMP consent info update failed: \(error)")
        }

        Task { @MainActor in
          if let rootVC = self?.currentRootViewController() {
            do {
              try await ConsentForm.loadAndPresentIfRequired(from: rootVC)
            } catch {
              print("UMP consent form failed: \(error)")
            }
          }
          await self?.startMobileAdsAndPreload()
        }
      }
  }

  private func startMobileAdsAndPreload() async {
    MobileAds.shared.start { _ in }
    async let interstitialLoad: () = preloadInterstitial()
    async let rewardedLoad: () = preloadRewardedAd()
    _ = await (interstitialLoad, rewardedLoad)
  }

  private func preloadInterstitial() async {
    do {
      let ad = try await InterstitialAd.load(
        with: interstitialAdUnitID,
        request: Request()
      )
      ad.fullScreenContentDelegate = self
      interstitial = ad
      isReady = true
    } catch {
      print("Failed to preload interstitial: \(error)")
      isReady = false
    }
  }

  private func preloadRewardedAd() async {
    do {
      let ad = try await RewardedAd.load(
        with: rewardedAdUnitID,
        request: Request()
      )
      ad.fullScreenContentDelegate = self
      rewardedAd = ad
      rewardedReady = true
    } catch {
      print("Failed to preload rewarded: \(error)")
      rewardedReady = false
    }
  }

  // MARK: - Counter

  /// Increment the "levels played" counter — call once when a level
  /// finishes (complete or failed). Suppressed entirely for Remove Ads
  /// holders so the counter never accumulates while the entitlement is
  /// held; if it ever lapses, ads start fresh from zero rather than
  /// firing a backlog.
  func recordLevelPlayed() {
    guard !StoreService.shared.hasRemoveAds else { return }
    levelsSinceLastAd += 1
  }

  // MARK: - Presentation

  /// Frequency-capped interstitial presentation. The `onDismiss` callback
  /// always fires — either after the ad's dismissal, or immediately when
  /// the cap is not yet reached, when the ad has not yet loaded, or when
  /// no host view controller is available. The counter is NOT mutated
  /// here — call `recordLevelPlayed()` from the gameplay flow to drive
  /// it. Callers can unconditionally chain the follow-up navigation in
  /// `onDismiss` without branching themselves.
  func showInterstitialIfReady(onDismiss: @escaping () -> Void) {
    guard !StoreService.shared.hasRemoveAds else {
      onDismiss()
      return
    }

    guard levelsSinceLastAd >= frequency else {
      onDismiss()
      return
    }

    guard let interstitial,
          let rootVC = currentRootViewController()
    else {
      onDismiss()
      return
    }

    pendingDismissCallback = onDismiss
    levelsSinceLastAd = 0
    LogService.shared.log("interstitial_shown", [
      "frequency": frequency,
    ])
    interstitial.present(from: rootVC)
  }

  // MARK: - Rewarded presentation

  /// Presents the rewarded ad. The `onReward` callback fires only when the
  /// SDK confirms the user earned the reward (watched the ad through). The
  /// `onSkip` callback fires in three cases: the ad was not loaded, no
  /// host view controller is available, or the user dismissed the ad
  /// before the reward was earned. Remove Ads holders are short-circuited
  /// straight to `onReward` with no ad shown.
  func showRewardedAdIfReady(
    onReward: @escaping () -> Void,
    onSkip: @escaping () -> Void
  ) {
    if StoreService.shared.hasRemoveAds {
      onReward()
      return
    }

    guard let rewardedAd,
          let rootVC = currentRootViewController()
    else {
      onSkip()
      return
    }

    pendingRewardedReward = onReward
    pendingRewardedSkip = onSkip

    LogService.shared.log("rewarded_ad_shown", ["context": "revive"])
    rewardedAd.present(from: rootVC) { [weak self] in
      Task { @MainActor in
        guard let self else { return }
        let reward = self.pendingRewardedReward
        self.pendingRewardedReward = nil
        self.pendingRewardedSkip = nil
        reward?()
      }
    }
  }

  // MARK: - Helpers

  private func currentRootViewController() -> UIViewController? {
    let scene = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .first
    guard var top = scene?.keyWindow?.rootViewController else { return nil }
    // Walk up the presentation chain — the SDK can't present from a
    // view controller that's already presenting something (e.g. the root
    // tab controller while LevelGameView is being shown as a fullScreenCover).
    while let presented = top.presentedViewController {
      top = presented
    }
    return top
  }
}

extension AdsService: FullScreenContentDelegate {
  nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
    Task { @MainActor in
      // Route to the matching cleanup path. The two ad formats use
      // disjoint state and different callback semantics.
      if let rewardedAd, ad === rewardedAd {
        self.rewardedAd = nil
        rewardedReady = false
        // If the reward closure didn't fire (user closed early), invoke
        // the skip callback. Otherwise the reward closure already cleared
        // both pendings.
        let skip = pendingRewardedSkip
        pendingRewardedReward = nil
        pendingRewardedSkip = nil
        skip?()
        await preloadRewardedAd()
        return
      }

      interstitial = nil
      isReady = false
      let callback = pendingDismissCallback
      pendingDismissCallback = nil
      callback?()
      await preloadInterstitial()
    }
  }

  nonisolated func ad(
    _ ad: FullScreenPresentingAd,
    didFailToPresentFullScreenContentWithError error: Error
  ) {
    Task { @MainActor in
      print("Ad failed to present: \(error)")
      if let rewardedAd, ad === rewardedAd {
        let skip = pendingRewardedSkip
        pendingRewardedReward = nil
        pendingRewardedSkip = nil
        skip?()
        return
      }
      let callback = pendingDismissCallback
      pendingDismissCallback = nil
      callback?()
    }
  }
}
