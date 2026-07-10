import Foundation
import Network

/// Forces iOS to show the Local Network permission prompt by starting a short
/// Bonjour browse for Cast services.
///
/// iOS only presents that prompt — and only then adds the "Local Network" toggle
/// to the app's Settings page — once the app actually attempts local-network
/// access via the system networking APIs. The Google Cast SDK's own discovery
/// does NOT reliably trigger it, which leaves discovery permanently returning
/// zero devices with no way for the user to grant access (the toggle never
/// appears). Kicking off an `NWBrowser` for `_googlecast._tcp` reliably triggers
/// the prompt; once granted, the Cast SDK's discovery starts seeing receivers.
@MainActor
final class LocalNetworkNudge {
    private var browser: NWBrowser?

    /// Start (or restart) a Bonjour browse to provoke the permission prompt. Safe
    /// to call repeatedly — backs the "Search Again" affordance too.
    func trigger() {
        browser?.cancel()
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_googlecast._tcp", domain: nil), using: params)
        // Handlers are required for the browse to actually run; we don't consume
        // the results (the Cast SDK owns real discovery) — this only exists to
        // trip the OS permission prompt.
        browser.stateUpdateHandler = { _ in }
        browser.browseResultsChangedHandler = { _, _ in }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    nonisolated deinit {}
}
