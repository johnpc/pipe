import Foundation

/// Base URL of the optional fallback Piped instance ("" = none). Mirrored from
/// Settings like `pipedBase`, so the network layer needs no AppSettings.
var pipedFallbackBase = ""

/// Which configured instance requests try first. Explicit state (see
/// docs/state-machines.md): after the primary fails and the fallback answers,
/// requests go to the fallback first for `InstanceFailover.holdSeconds`, so a
/// dead primary costs its retry budget once rather than on every request; when
/// the hold lapses the primary is tried first again.
enum InstanceRoute: Equatable {
    case primary
    case fallback(until: Date)
}

/// Holds the current `InstanceRoute`. One shared router serves the app (once
/// the primary is known dead, every caller should skip it for the hold); tests
/// pass their own so they never share state with other suites.
final class InstanceRouter: @unchecked Sendable {
    static let shared = InstanceRouter()
    private let lock = NSLock()
    private var current: InstanceRoute

    init(_ route: InstanceRoute = .primary) { current = route }

    var route: InstanceRoute {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }
}

/// One place a request can go: the instance base it targets and the full URL.
struct InstanceCandidate: Equatable {
    let base: String
    let url: URL
}

/// Pure failover decisions for `PipedAPI.fetch`: which instances to try, in
/// what order, when to move on to the next, and the route after a success.
enum InstanceFailover {
    /// How long a successful fallback stays first in line.
    static let holdSeconds: TimeInterval = 300

    /// The instances to try for `url`, in order. A URL not built on the primary
    /// base (an absolute media/caption URL) is only ever tried as-is; so is any
    /// URL when no distinct fallback is configured.
    static func candidates(for url: URL, primary: String, fallback: String,
                           route: InstanceRoute, now: Date) -> [InstanceCandidate] {
        let own = InstanceCandidate(base: primary, url: url)
        guard !fallback.isEmpty, fallback != primary,
              let alternate = rebase(url, from: primary, to: fallback) else { return [own] }
        let other = InstanceCandidate(base: fallback, url: alternate)
        return prefersFallback(route, now: now) ? [other, own] : [own, other]
    }

    /// `url` with its `from` prefix swapped for `to`; nil when `url` isn't on `from`.
    static func rebase(_ url: URL, from: String, to: String) -> URL? {
        let absolute = url.absoluteString
        guard !from.isEmpty, absolute == from || absolute.hasPrefix(from + "/") || absolute.hasPrefix(from + "?") else {
            return nil
        }
        return URL(string: to + absolute.dropFirst(from.count))
    }

    /// Whether the fallback hold is still in force at `now`.
    static func prefersFallback(_ route: InstanceRoute, now: Date) -> Bool {
        if case .fallback(let until) = route { return now < until }
        return false
    }

    /// Whether a failure means "this instance is unreachable", so the next
    /// instance is worth a try. Same classification as the retry policy:
    /// connectivity errors and gateway statuses; an instance's own verdict (4xx,
    /// 500, a Piped error envelope, bad JSON) is final and never re-asked.
    static func shouldTryNext(after error: Error) -> Bool {
        RetryPolicy.isTransient(error)
    }

    /// The route after a request succeeded on `base`.
    static func route(afterSuccessOn base: String, primary: String, now: Date) -> InstanceRoute {
        base == primary ? .primary : .fallback(until: now.addingTimeInterval(holdSeconds))
    }
}
