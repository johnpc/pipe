import Foundation
import Network

/// Starts a raw Bonjour browse for Cast services (`_googlecast._tcp`) via Apple's
/// Network framework. Serves two purposes:
///
///  1. It reliably trips the iOS Local Network permission prompt (and thus adds
///     the Settings toggle) — the Google Cast SDK's own discovery does not.
///  2. It's an independent second opinion on discovery: the SAME mechanism
///     `dns-sd` uses. When the Cast SDK reports zero devices, comparing against
///     what this browser sees tells us whether the fault is the Cast SDK's
///     resolution/filtering (browser sees devices, SDK doesn't) or the network/OS
///     (neither sees anything). Results are reported via `onResults` for logging.
@MainActor
final class LocalNetworkNudge {
    private var browser: NWBrowser?
    /// Called with the browse state and count of discovered endpoints whenever it
    /// changes, so the caller can log an independent view of discovery.
    var onResults: ((_ state: String, _ count: Int) -> Void)?

    /// Start (or restart) the browse. Safe to call repeatedly — backs both init
    /// and the "Search Again" affordance.
    func trigger() {
        browser?.cancel()
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(for: .bonjour(type: "_googlecast._tcp", domain: nil), using: params)
        browser.stateUpdateHandler = { [weak self] state in
            let desc = "\(state)"
            Task { @MainActor in self?.onResults?(desc, 0) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let count = results.count
            Task { @MainActor in self?.onResults?("results", count) }
        }
        browser.start(queue: .main)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        browser = nil
    }

    nonisolated deinit {}
}
