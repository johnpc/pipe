import Testing
import Foundation
@testable import pipe

@MainActor
@Suite(.serialized)
struct FeedLoaderTests {
    @Test func emptyChannelsReturnsEmpty() async {
        let result = await FeedLoader.fetch(channels: [])
        #expect(result == [])
    }

    @Test func sortsNewestFirstAcrossChannels() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        // Every channel fetch returns the same stubbed channel with two streams.
        MockURLProtocol.stub(json: #"{"id":"c","name":"C","avatarUrl":null,"description":null,"relatedStreams":[{"url":"/watch?v=old","title":"Old","thumbnail":"t","duration":1,"uploaderName":"U","uploadedDate":null,"uploaded":100},{"url":"/watch?v=new","title":"New","thumbnail":"t","duration":1,"uploaderName":"U","uploadedDate":null,"uploaded":900}],"tabs":null,"nextpage":null}"#)
        let result = await FeedLoader.fetch(channels: [FollowedChannel(id: "c", name: "C", thumbnail: "")])
        #expect(result?.first?.videoId == "new")
        #expect(result?.last?.videoId == "old")
    }

    @Test func nilWhenNetworkYieldsNothing() async {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stubError(URLError(.notConnectedToInternet))
        let result = await FeedLoader.fetch(channels: [FollowedChannel(id: "c", name: "C", thumbnail: "")])
        #expect(result == nil)
    }
}
