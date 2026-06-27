import Testing
import Foundation
@testable import pipe

struct FeedCacheTests {

    // MARK: - FeedCachePolicy (pure)

    @Test func freshWithinTTL() {
        let cachedAt = Date(timeIntervalSince1970: 1000)
        let now = Date(timeIntervalSince1970: 1000 + 60) // 1 min later
        #expect(FeedCachePolicy.isFresh(cachedAt: cachedAt, now: now) == true)
    }

    @Test func staleAfterTTL() {
        let cachedAt = Date(timeIntervalSince1970: 1000)
        let now = Date(timeIntervalSince1970: 1000 + 16 * 60) // past 15-min TTL
        #expect(FeedCachePolicy.isFresh(cachedAt: cachedAt, now: now) == false)
    }

    @Test func customTTLRespected() {
        let cachedAt = Date(timeIntervalSince1970: 0)
        let now = Date(timeIntervalSince1970: 5)
        #expect(FeedCachePolicy.isFresh(cachedAt: cachedAt, now: now, ttl: 10) == true)
        #expect(FeedCachePolicy.isFresh(cachedAt: cachedAt, now: now, ttl: 3) == false)
    }

    // MARK: - FeedCache (UserDefaults-backed)

    private func makeCache() -> FeedCache {
        FeedCache(defaults: UserDefaults(suiteName: "feedcache-\(UUID().uuidString)")!)
    }

    private func stream(_ id: String) -> RelatedStream {
        RelatedStream(url: "/watch?v=\(id)", title: "T-\(id)", thumbnail: "t", duration: 10, uploaderName: "U", uploadedDate: nil, uploaded: 1)
    }

    @Test func emptyCacheReturnsNil() {
        let cache = makeCache()
        #expect(cache.cachedVideos() == nil)
        #expect(cache.cachedAt() == nil)
        #expect(cache.isFresh() == false)
    }

    @Test func saveAndReadRoundTrips() {
        let cache = makeCache()
        cache.save([stream("a"), stream("b")], now: Date(timeIntervalSince1970: 5000))
        let read = cache.cachedVideos()
        #expect(read?.count == 2)
        #expect(read?.first?.videoId == "a")
        #expect(cache.cachedAt() == Date(timeIntervalSince1970: 5000))
    }

    @Test func freshnessReflectsStamp() {
        let cache = makeCache()
        cache.save([stream("a")], now: Date(timeIntervalSince1970: 1000))
        #expect(cache.isFresh(now: Date(timeIntervalSince1970: 1000 + 60)) == true)
        #expect(cache.isFresh(now: Date(timeIntervalSince1970: 1000 + 16 * 60)) == false)
    }

    @Test func persistsAcrossInstances() {
        let suite = UserDefaults(suiteName: "feedcache-persist-\(UUID().uuidString)")!
        FeedCache(defaults: suite).save([stream("x")], now: Date(timeIntervalSince1970: 9000))
        let reopened = FeedCache(defaults: suite)
        #expect(reopened.cachedVideos()?.first?.videoId == "x")
    }
}
