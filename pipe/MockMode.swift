import Foundation

/// Wires the app to serve bundled fixtures when launched for UI testing.
enum MockMode {
    static let launchArgument = "--uitest-mock"

    /// True when the process was launched in UI-test mock mode.
    static func isEnabled(_ args: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        args.contains(launchArgument)
    }

    /// Point PipedAPI at a fixture-backed session.
    static func activate() {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [FixtureURLProtocol.self]
        PipedAPI.session = URLSession(configuration: config)
    }

    static let failArgument = "--uitest-fail-streams"

    /// Activate only when the launch argument is present. Also honors a flag that
    /// makes `/streams/` requests error, for the error-recovery UI test.
    static func activateIfNeeded(_ args: [String] = ProcessInfo.processInfo.arguments) {
        guard isEnabled(args) else { return }
        resetPersistedState()
        FixtureURLProtocol.failStreams = args.contains(failArgument)
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

    /// Injectable core of the reset, so it's unit-testable against a scratch
    /// defaults suite and temp directory without touching global state.
    static func reset(defaults: UserDefaults, domain: String?, downloads: URL) {
        if let domain { defaults.removePersistentDomain(forName: domain) }
        try? FileManager.default.removeItem(at: downloads)
    }
}
