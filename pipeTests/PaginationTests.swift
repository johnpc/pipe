import Testing
import Foundation
@testable import pipe

struct PaginationTests {

    private func s(_ id: String) -> RelatedStream {
        RelatedStream(url: "/watch?v=\(id)", title: id, thumbnail: "", duration: 0, uploaderName: "U", uploadedDate: nil, uploaded: 1)
    }

    @Test func mergeAppendsNewItems() {
        let out = Pagination.merge([s("a"), s("b")], [s("c"), s("d")])
        #expect(out.map(\.videoId) == ["a", "b", "c", "d"])
    }

    @Test func mergeDedupesAcrossPageBoundary() {
        let out = Pagination.merge([s("a"), s("b")], [s("b"), s("c")])
        #expect(out.map(\.videoId) == ["a", "b", "c"])
    }

    @Test func mergeEmptyPageIsNoOp() {
        let out = Pagination.merge([s("a")], [])
        #expect(out.map(\.videoId) == ["a"])
    }

    @Test func hasMoreForNonEmptyToken() {
        #expect(Pagination.hasMore("tok") == true)
    }

    @Test func hasMoreFalseForNilOrBlank() {
        #expect(Pagination.hasMore(nil) == false)
        #expect(Pagination.hasMore("") == false)
        #expect(Pagination.hasMore("   ") == false)
    }
}

@MainActor
@Suite(.serialized)
struct ChannelNextPageTests {
    @Test func nextPageURLEncodesToken() {
        let url = PipedAPI.channelNextPageURL(channelId: "UC1", nextpage: "a b&c")
        #expect(url.absoluteString.contains("/nextpage/channel/UC1"))
        #expect(url.absoluteString.contains("nextpage="))
        #expect(!url.absoluteString.contains("a b&c"))
    }

    @Test func channelNextPageDecodes() async throws {
        PipedAPI.session = MockURLProtocol.makeSession()
        defer { PipedAPI.session = .shared }
        MockURLProtocol.stub(json: #"{"content":[{"url":"/watch?v=v9","title":"More","thumbnail":"t","duration":30,"uploaderName":"U","uploadedDate":null,"uploaded":1}],"nextpage":"tok2"}"#)
        let page = try await PipedAPI.channelNextPage(channelId: "UC1", nextpage: "tok1")
        #expect(page.content.first?.videoId == "v9")
        #expect(page.nextpage == "tok2")
    }
}
