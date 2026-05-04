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
  #else
    private let interstitialAdUnitID = "ca-app-pub-9259578521352937/6262225438"
  #endif

  /// Show an interstitial at most once every `frequency` levels played
  /// (a level "played" = the player either completed it or failed it).
  private let frequency: Int = 3

  // MARK: - State

  @Published private(set) var isReady: Bool = false

  private var interstitial: InterstitialAd?
  private var levelsSinceLastAd: Int = 0
  private var pendingDismissCallback: (() -> Void)?

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
    await preloadInterstitial()
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
    interstitial.present(from: rootVC)
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
      let callback = pendingDismissCallback
      pendingDismissCallback = nil
      callback?()
    }
  }
}
