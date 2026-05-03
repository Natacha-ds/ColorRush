import Combine
import Foundation
import RevenueCat

@MainActor
final class StoreService: ObservableObject {
  static let shared = StoreService()

  private static let apiKey = "appl_qwmdfKXKKrZQWTQQofnvTIixBzJ"
  private static let entitlementID = "remove_ads"

  private let entitlementCacheKey = "iap.removeAds.hasEntitlement"

  @Published private(set) var package: Package?
  @Published private(set) var hasRemoveAds: Bool

  private var customerInfoTask: Task<Void, Never>?

  private init() {
    // Cold-start gate: read the cached entitlement so ads are correctly
    // suppressed before RevenueCat's network refresh resolves.
    hasRemoveAds = UserDefaults.standard.bool(forKey: entitlementCacheKey)

    Purchases.logLevel = .info
    Purchases.configure(withAPIKey: Self.apiKey)

    Task { await loadOfferings() }
    Task { await refreshEntitlement() }
    customerInfoTask = Task { [weak self] in
      for await customerInfo in Purchases.shared.customerInfoStream {
        await self?.handle(customerInfo)
      }
    }
  }

  deinit {
    customerInfoTask?.cancel()
  }

  // MARK: - Offerings

  private func loadOfferings() async {
    do {
      let offerings = try await Purchases.shared.offerings()
      // Prefer the conventional "Lifetime" package; fall back to the first
      // available package on the current offering if the convention isn't met.
      package = offerings.current?.lifetime ?? offerings.current?
        .availablePackages.first
    } catch {
      print("Failed to load offerings: \(error)")
    }
  }

  // MARK: - Entitlement refresh

  private func refreshEntitlement() async {
    do {
      let customerInfo = try await Purchases.shared.customerInfo()
      handle(customerInfo)
    } catch {
      print("Failed to fetch customer info: \(error)")
    }
  }

  private func handle(_ customerInfo: CustomerInfo) {
    let entitled = customerInfo.entitlements[Self.entitlementID]?
      .isActive == true
    setEntitlement(entitled)
  }

  private func setEntitlement(_ value: Bool) {
    hasRemoveAds = value
    UserDefaults.standard.set(value, forKey: entitlementCacheKey)
  }

  // MARK: - Purchase

  /// Triggers RevenueCat's purchase sheet for the Remove Ads package. Returns
  /// `true` if the purchase succeeded and the entitlement is now held,
  /// `false` if the user cancelled.
  @discardableResult
  func purchase() async throws -> Bool {
    guard let package else { return false }

    let result = try await Purchases.shared.purchase(package: package)

    guard !result.userCancelled else { return false }

    handle(result.customerInfo)
    return result.customerInfo.entitlements[Self.entitlementID]?
      .isActive == true
  }

  // MARK: - Restore

  /// Forces a restore of prior purchases on the current Apple ID and
  /// re-checks entitlements.
  func restore() async throws {
    let customerInfo = try await Purchases.shared.restorePurchases()
    handle(customerInfo)
  }
}
