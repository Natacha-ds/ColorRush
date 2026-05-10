import Foundation
#if canImport(UIKit)
  import UIKit
#endif

/// Lightweight event logger.
/// - Persists a stable per-install `sessionId` in UserDefaults so events can
///   be stitched together across launches.
/// - In RELEASE builds, posts each event fire-and-forget to the negotiator
///   endpoint. In DEBUG builds, the network call is skipped entirely and the
///   payload is printed to the console — keeps local dev free of noise on
///   the prod log stream.
final class LogService {
  static let shared = LogService()

  private static let sessionKey = "cr.session_id"
  private static let endpoint = URL(
    string: "https://nicode.bichu.fr/negotiator/colorRush/session"
  )!

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
      // the prod negotiator stream.
      return
    #else
      queue.async { [weak self] in
        self?.postEvent(event: event, payload: payload, session: session)
      }
    #endif
  }

  private func postEvent(event: String, payload: [String: Any], session: String) {
    let stringPayload = (try? JSONSerialization.data(withJSONObject: payload))
      .flatMap { String(data: $0, encoding: .utf8) } ?? ""

    let body: [String: Any] = [
      "event": event,
      "session": session,
      "platform": "iOS",
      "osVersion": Self.osVersion,
      "source": "",
      "language": Locale.preferredLanguages.first ?? "??",
      "payload": stringPayload,
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: body) else { return }

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
