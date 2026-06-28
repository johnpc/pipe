import Testing
import Foundation
@testable import pipe

@MainActor
struct FeedLoaderTests {
    // Session-mutating FeedLoader tests live in PipedAPITests (the one serialized
    // session suite). This covers the no-network-needed branch.
    @Test func emptyChannelsReturnsEmpty() async {
        let result = await FeedLoader.fetch(channels: [])
        #expect(result == [])
    }
}
