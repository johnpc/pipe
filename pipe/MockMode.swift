import Foundation

/// Wires the app to serve bundled fixtures when launched for UI testing.
enum MockMode {
    static let launchArgument = "--uitest-mock"

    /// `--uitest-instance <url>`: hermetic launch (state wiped, Cast inert) that
    /// talks to a real HTTP backend — the bundled fake Piped server
    /// (`scripts/fake_piped`) — instead of in-process fixtures, so scenarios can
    /// play actual media end to end.
    static let instanceArgument = "--uitest-instance"

    /// `--uitest-fallback-instance <url>`: also configure a fallback instance,
    /// so a scenario can point the primary at a dead address and prove the app
    /// carries on through the fallback.
    static let fallbackArgument = "--uitest-fallback-instance"

    /// True when the process was launched for UI testing (fixtures or a fake
    /// backend): persisted state is reset and the Cast SDK stays inert.
    static func isEnabled(_ args: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        args.contains(launchArgument) || instanceOverride(args) != nil
    }

    /// The backend URL given after `--uitest-instance`, if any.
    static func instanceOverride(_ args: [String] = ProcessInfo.processInfo.arguments) -> String? {
        value(after: instanceArgument, in: args)
    }

    /// The fallback instance given after `--uitest-fallback-instance`, if any.
    static func fallbackOverride(_ args: [String] = ProcessInfo.processInfo.arguments) -> String? {
        value(after: fallbackArgument, in: args)
    }

    private static func value(after flag: String, in args: [String]) -> String? {
        guard let index = args.firstIndex(of: flag), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    /// Point PipedAPI at a fixture-backed session.
    static func activate() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureURLProtocol.self]
        PipedAPI.session = URLSession(configuration: config)
    }

    /// Leave the instance unconfigured, so the setup screen can be tested.
    static let noInstanceArgument = "--uitest-no-instance"
    static let failArgument = "--uitest-fail-streams"
    static let errorArgument = "--uitest-error-streams"
    static let downArgument = "--uitest-down-instance"

    /// Activate only when the launch argument is present. Also honors flags that
    /// make `/streams/` requests fail (network error, for the Retry UI), return
    /// a Piped error envelope (for the real-message error toast), or answer like
    /// a proxy whose instance is down (HTTP 502, for the status-naming toast).
    static func activateIfNeeded(_ args: [String] = ProcessInfo.processInfo.arguments) {
        guard isEnabled(args) else { return }
        resetPersistedState()
        if let instance = instanceOverride(args) {
            pointInstance(at: instance, defaults: .standard)
            if let fallback = fallbackOverride(args) { UserDefaults.standard.set(fallback, forKey: AppSettings.fallbackKey) }
            return
        }
        // Fixtures answer by path, so any host works; without one the app would
        // sit on the setup screen (which only `--uitest-no-instance` wants).
        if !args.contains(noInstanceArgument) { pointInstance(at: "https://fixtures.uitest", defaults: .standard) }
        FixtureURLProtocol.streamMode = .from(arguments: args)
        activate()
    }

    /// Wipe persisted app state so every UI-test launch starts hermetic — no
    /// downloads, follows, saves, or history bleeding across scenarios (which
    /// flip conditional UI like the "Download" vs "Remove Download" menu).
    static func resetPersistedState() {
        reset(defaults: .standard,
              domain: Bundle.main.bundleIdentifier,
              downloads: DownloadStore.defaultDirectory())
    }

    /// Make `AppSettings` (created later) start on `instance`: the fake server
    /// in CI, or any backend a developer wants to drive the app against.
    static func pointInstance(at instance: String, defaults: UserDefaults) {
        defaults.set(instance, forKey: AppSettings.instanceKey)
    }

    /// Injectable core of the reset, so it's unit-testable against a scratch
    /// defaults suite and temp directory without touching global state.
    static func reset(defaults: UserDefaults, domain: String?, downloads: URL) {
        if let domain { defaults.removePersistentDomain(forName: domain) }
        try? FileManager.default.removeItem(at: downloads)
    }
}
