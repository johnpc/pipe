import Testing
import Foundation
@testable import pipe

/// Pure failover decisions — no globals, no network, safe in parallel. The
/// end-to-end path through `PipedAPI.fetch` is in `PipedAPITests`.
struct InstanceFailoverTests {
    private let primary = "https://primary.test"
    private let fallback = "https://fallback.test"
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private var searchURL: URL { URL(string: "https://primary.test/search?q=x&filter=all")! }

    @Test func noFallbackMeansOnlyThePrimary() {
        let c = InstanceFailover.candidates(for: searchURL, primary: primary, fallback: "", route: .primary, now: now)
        #expect(c == [InstanceCandidate(base: primary, url: searchURL)])
    }

    @Test func aFallbackEqualToThePrimaryIsIgnored() {
        let c = InstanceFailover.candidates(for: searchURL, primary: primary, fallback: primary, route: .primary, now: now)
        #expect(c.count == 1)
    }

    @Test func primaryFirstThenTheSameRequestOnTheFallback() {
        let c = InstanceFailover.candidates(for: searchURL, primary: primary, fallback: fallback, route: .primary, now: now)
        #expect(c.map(\.base) == [primary, fallback])
        #expect(c[1].url.absoluteString == "https://fallback.test/search?q=x&filter=all")
    }

    @Test func duringTheHoldTheFallbackGoesFirst() {
        let route = InstanceRoute.fallback(until: now.addingTimeInterval(1))
        let c = InstanceFailover.candidates(for: searchURL, primary: primary, fallback: fallback, route: route, now: now)
        #expect(c.map(\.base) == [fallback, primary])
    }

    @Test func anExpiredHoldGoesBackToThePrimaryFirst() {
        let route = InstanceRoute.fallback(until: now)
        let c = InstanceFailover.candidates(for: searchURL, primary: primary, fallback: fallback, route: route, now: now)
        #expect(c.map(\.base) == [primary, fallback])
    }

    @Test func aURLNotOnThePrimaryIsOnlyTriedAsIs() {
        // An absolute media/caption URL from the instance's proxy, or a lookalike host.
        for raw in ["https://proxy.example/videoplayback?id=1", "https://primary.test.evil/search"] {
            let url = URL(string: raw)!
            let c = InstanceFailover.candidates(for: url, primary: primary, fallback: fallback, route: .primary, now: now)
            #expect(c == [InstanceCandidate(base: primary, url: url)])
        }
    }

    @Test func rebaseSwapsOnlyTheInstancePrefix() {
        #expect(InstanceFailover.rebase(URL(string: "https://primary.test/streams/abc")!, from: primary, to: fallback)?
            .absoluteString == "https://fallback.test/streams/abc")
        #expect(InstanceFailover.rebase(URL(string: "https://primary.test")!, from: primary, to: fallback)?
            .absoluteString == fallback)
        #expect(InstanceFailover.rebase(URL(string: "https://primary.test?x=1")!, from: primary, to: fallback)?
            .absoluteString == "https://fallback.test?x=1")
        #expect(InstanceFailover.rebase(URL(string: "https://other.test/x")!, from: primary, to: fallback) == nil)
        #expect(InstanceFailover.rebase(URL(string: "https://primary.test/x")!, from: "", to: fallback) == nil)
    }

    @Test func onlyAnUnreachableInstanceMovesOnToTheNext() {
        #expect(InstanceFailover.shouldTryNext(after: URLError(.cannotConnectToHost)))
        #expect(InstanceFailover.shouldTryNext(after: URLError(.timedOut)))
        #expect(InstanceFailover.shouldTryNext(after: PipedError.http(502)))
        // The instance's own answer is final: asking another one would hide it.
        #expect(!InstanceFailover.shouldTryNext(after: PipedError.http(404)))
        #expect(!InstanceFailover.shouldTryNext(after: PipedError.http(500)))
        #expect(!InstanceFailover.shouldTryNext(after: PipedError(message: "Video unavailable")))
        #expect(!InstanceFailover.shouldTryNext(after: URLError(.badURL)))
    }

    @Test func successSetsTheRoute() {
        #expect(InstanceFailover.route(afterSuccessOn: primary, primary: primary, now: now) == .primary)
        #expect(InstanceFailover.route(afterSuccessOn: fallback, primary: primary, now: now)
            == .fallback(until: now.addingTimeInterval(InstanceFailover.holdSeconds)))
    }

    @Test func prefersFallbackOnlyInsideTheHold() {
        #expect(!InstanceFailover.prefersFallback(.primary, now: now))
        #expect(InstanceFailover.prefersFallback(.fallback(until: now.addingTimeInterval(0.1)), now: now))
        #expect(!InstanceFailover.prefersFallback(.fallback(until: now.addingTimeInterval(-0.1)), now: now))
    }

    @Test func routerStoresTheRoute() {
        let router = InstanceRouter()
        #expect(router.route == .primary)
        router.route = .fallback(until: now)
        #expect(router.route == .fallback(until: now))
        #expect(InstanceRouter(.fallback(until: now)).route == .fallback(until: now))
    }

    @Test func anATSRefusalBecomesAClearMessage() {
        let translated = PipedError.translated(URLError(.appTransportSecurityRequiresSecureConnection))
        #expect(translated as? PipedError == PipedError.insecureInstance)
        let other = PipedError.translated(URLError(.timedOut))
        #expect((other as? URLError)?.code == .timedOut)
    }
}
