import Testing
import Foundation
@testable import pipe

struct SearchFilterTests {
    private func item(_ type: String, _ url: String) -> SearchItem {
        SearchItem(url: url, type: type, title: "t", thumbnail: nil, uploaderName: nil, uploaderUrl: nil, duration: nil, name: nil, uploadedDate: nil, verified: nil, subscribers: nil, videos: nil)
    }
    private var mixed: [SearchItem] {
        [item("channel", "/channel/c1"), item("stream", "/watch?v=v1"), item("playlist", "/playlist?list=p1"), item("stream", "/watch?v=v2")]
    }

    @Test func filtersByKind() {
        #expect(SearchFilter.all.apply(mixed).count == 4)
        #expect(SearchFilter.videos.apply(mixed).map(\.url) == ["/watch?v=v1", "/watch?v=v2"])
        #expect(SearchFilter.channels.apply(mixed).map(\.url) == ["/channel/c1"])
        #expect(SearchFilter.playlists.apply(mixed).map(\.url) == ["/playlist?list=p1"])
    }

    @Test func labelsAndPipedValues() {
        #expect(SearchFilter.allCases.map(\.label) == ["All", "Videos", "Channels", "Playlists"])
        #expect(SearchFilter.allCases.map(\.pipedValue) == ["all", "videos", "channels", "playlists"])
    }

    @Test func searchURLCarriesTheFilter() {
        #expect(PipedAPI.searchURL("a b").absoluteString.hasSuffix("/search?q=a%20b&filter=all"))
        #expect(PipedAPI.searchURL("x", filter: .channels).absoluteString.hasSuffix("/search?q=x&filter=channels"))
    }
}
