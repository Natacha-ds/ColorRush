import Foundation
#if canImport(UIKit)
  import UIKit
#endif

/// Lightweight event logger.
/// - Persists a stable per-install `sessionId` in UserDefaults so events can
///   be stitched together across launches.
/// - In RELEASE builds, posts each event fire-and-forget to PostHog. In DEBUG
///   builds, the network call is skipped entirely and the payload is printed
///   to the console — keeps local dev free of noise on the prod event stream.
final class LogService {
  static let shared = LogService()

  private static let sessionKey = "cr.session_id"
  /// PostHog project key: public by design, meant to ship in the client.
  private static let apiKey = "phc_AsSidN2fjkebi7zFjtwYVUhuHdWZfkpWpbHsRzyVsH3c"
  private static let endpoint = URL(string: "https://eu.i.posthog.com/i/v0/e/")!

  private(set) var sessionId: String?
  private let queue = DispatchQueue(label: "cr.log", qos: .utility)
  private let urlSession: URLSession

  private init() {
    let config = URLSessionConfiguration.ephemeral
    config.waitsForConnectivity = false
    config.timeoutIntervalForRequest = 5
    config.timeoutIntervalForResource = 10
    self.urlSession = URLSession(configuration: config)
  }

  /// Loads or generates the session id. Should be called once at app launch.
  /// Returns whether this is the first launch (no prior session id).
  @discardableResult
  func bootstrap() -> Bool {
    let defaults = UserDefaults.standard
    if let stored = defaults.string(forKey: Self.sessionKey) {
      sessionId = stored
      return false
    }
    let generated = "cr_\(Self.randomToken(length: 12))"
    defaults.set(generated, forKey: Self.sessionKey)
    sessionId = generated
    return true
  }

  /// Standard event log. Payload values must be JSON-serialisable.
  func log(_ event: String, _ payload: [String: Any] = [:]) {
    enqueue(event: event, payload: payload, level: "info")
  }

  /// Error-level event log. Same transport, separate level for filtering.
  func error(_ event: String, _ payload: [String: Any] = [:]) {
    enqueue(event: event, payload: payload, level: "error")
  }

  // MARK: - Private

  private func enqueue(event: String, payload: [String: Any], level: String) {
    let session = sessionId ?? "<uninitialised>"
    #if DEBUG
      print("[LOG \(level)] [\(session)] \(event) \(payload)")
      // Skip the HTTP POST entirely in DEBUG so dev sessions don't pollute
      // the prod event stream.
      return
    #else
      // Captured here, not on the queue, so the timestamp reflects the moment
      // the event happened.
      let timestamp = Date()
      queue.async { [weak self] in
        self?.postEvent(
          event: event, payload: payload, session: session, level: level,
          timestamp: timestamp)
      }
    #endif
  }

  private func postEvent(
    event: String, payload: [String: Any], session: String, level: String,
    timestamp: Date
  ) {
    // JSONSerialization raises an Objective-C exception, which `try?` cannot
    // catch, on a non-JSON value. An invalid payload is dropped rather than
    // crashing the app.
    var properties = JSONSerialization.isValidJSONObject(payload) ? payload : [:]
    properties["app"] = "color-rush"
    properties["$app_version"] = Self.appVersion
    properties["$os"] = "iOS"
    properties["$os_version"] = Self.osVersion
    properties["language"] = Locale.preferredLanguages.first ?? "??"
    properties["level"] = level
    // No person profile: the install id is enough for funnels and retention,
    // and nothing more than necessary is stored.
    properties["$process_person_profile"] = false

    let body: [String: Any] = [
      "api_key": Self.apiKey,
      "event": event,
      "distinct_id": session,
      "timestamp": ISO8601DateFormatter().string(from: timestamp),
      "properties": properties,
    ]

    guard JSONSerialization.isValidJSONObject(body),
      let data = try? JSONSerialization.data(withJSONObject: body)
    else { return }

    var request = URLRequest(url: Self.endpoint)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = data

    let task = urlSession.dataTask(with: request) { _, _, _ in
      // Fire-and-forget. Failures are intentionally ignored — we never want
      // logging to surface to the user, retry, or block subsequent events.
    }
    task.resume()
  }

  private static var appVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
      ?? "unknown"
  }

  private static var osVersion: String {
    #if canImport(UIKit)
      return UIDevice.current.systemVersion
    #else
      let v = ProcessInfo.processInfo.operatingSystemVersion
      return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    #endif
  }

  private static func randomToken(length: Int) -> String {
    let alphabet = "abcdefghijklmnopqrstuvwxyz0123456789"
    return String((0..<length).map { _ in alphabet.randomElement()! })
  }
}
