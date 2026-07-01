import Foundation

/// Stable, anonymous identity for attributing diagnostic logs to an install
/// without any account (matches the app's no-auth model). `deviceId` persists
/// across launches; `sessionId` is fresh each launch so events can be grouped
/// into a single playback session.
struct DeviceIdentity {
    let deviceId: String
    let sessionId: String
    let appVersion: String

    private static let deviceKey = "diagnosticsDeviceId"

    init(defaults: UserDefaults = .standard, sessionId: String = UUID().uuidString) {
        if let existing = defaults.string(forKey: Self.deviceKey) {
            deviceId = existing
        } else {
            let fresh = UUID().uuidString
            defaults.set(fresh, forKey: Self.deviceKey)
            deviceId = fresh
        }
        self.sessionId = sessionId
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        appVersion = "\(v ?? "0")(\(b ?? "0"))"
    }
}
