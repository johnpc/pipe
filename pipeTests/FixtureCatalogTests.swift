import Testing
import Foundation
@testable import pipe

struct FixtureCatalogTests {
    private let search = Data("""
    {"items":[{"url":"/channel/UC1","type":"channel","name":"MrBeast"},
              {"url":"/watch?v=abc","type":"stream","title":"First","uploaderName":"Up","duration":37,"thumbnail":"https://t/abc.jpg"},
              {"url":"/watch?v=def&list=x","type":"stream","title":"Second","uploaderName":"Up2","duration":100,"thumbnail":"https://t/def.jpg"}]}
    """.utf8)
    private let trending = Data("""
    [{"url":"/watch?v=ghi","title":"Trend","uploaderName":"Up3","duration":5,"thumbnail":"t"},{"url":"/watch?v=","title":"Broken"}]
    """.utf8)
    private let template = Data("""
    {"title":"Template","uploader":"Tmpl","duration":2104,"thumbnailUrl":"https://t/old.jpg","hls":null,"audioStreams":[],"videoStreams":[]}
    """.utf8)

    @Test func parsesWatchAndStreamsIds() {
        #expect(FixtureCatalog.videoId(fromWatchURL: "/watch?v=abc") == "abc")
        #expect(FixtureCatalog.videoId(fromWatchURL: "/watch?v=abc&list=PL") == "abc")
        #expect(FixtureCatalog.videoId(fromWatchURL: "/channel/UC1") == nil)
        #expect(FixtureCatalog.videoId(fromWatchURL: "/watch?v=") == nil)
        #expect(FixtureCatalog.videoId(fromStreamsPath: "/streams/abc") == "abc")
        #expect(FixtureCatalog.videoId(fromStreamsPath: "/streams/") == nil)
        #expect(FixtureCatalog.videoId(fromStreamsPath: "/search") == nil)
    }

    @Test func readsVideosOutOfItemsAndTopLevelArrays() {
        let items = FixtureCatalog.videos(in: search)
        #expect(items.map(\.videoId) == ["abc", "def"])  // the channel row is skipped
        #expect(items.first == FixtureVideo(videoId: "abc", title: "First", uploader: "Up", duration: 37, thumbnail: "https://t/abc.jpg"))
        #expect(FixtureCatalog.videos(in: trending).map(\.title) == ["Trend"])
    }

    @Test func readsRelatedStreamsAndContent() {
        let related = Data(#"{"relatedStreams":[{"url":"/watch?v=r1","title":"R"}]}"#.utf8)
        let content = Data(#"{"content":[{"url":"/watch?v=c1","title":"C"}],"nextpage":null}"#.utf8)
        #expect(FixtureCatalog.videos(in: related).map(\.videoId) == ["r1"])
        #expect(FixtureCatalog.videos(in: content).map(\.videoId) == ["c1"])
        #expect(FixtureCatalog.videos(in: Data("not json".utf8)).isEmpty)
        #expect(FixtureCatalog.videos(in: Data("42".utf8)).isEmpty)
    }

    @Test func looksUpAcrossSourcesInOrder() {
        let loader: (String) -> Data? = { name in
            switch name {
            case "search": return self.search
            case "trending": return self.trending
            default: return nil
            }
        }
        #expect(FixtureCatalog.video("ghi", loader: loader)?.title == "Trend")
        #expect(FixtureCatalog.video("abc", loader: loader)?.title == "First")
        #expect(FixtureCatalog.video("nope", loader: loader) == nil)
    }

    @Test func personalizeRewritesIdentityAndKeepsTheRest() throws {
        let video = FixtureVideo(videoId: "abc", title: "First", uploader: "Up", duration: 37, thumbnail: "https://t/abc.jpg")
        let out = FixtureCatalog.personalize(template, for: video)
        let json = try #require(try JSONSerialization.jsonObject(with: out) as? [String: Any])
        #expect(json["title"] as? String == "First")
        #expect(json["uploader"] as? String == "Up")
        #expect(json["duration"] as? Int == 37)
        #expect(json["thumbnailUrl"] as? String == "https://t/abc.jpg")
        #expect((json["audioStreams"] as? [Any])?.isEmpty == true)  // streams untouched
    }

    @Test func personalizeKeepsTemplateValuesForUnknownFields() throws {
        let video = FixtureVideo(videoId: "abc", title: "First", uploader: "", duration: 0, thumbnail: "")
        let json = try #require(try JSONSerialization.jsonObject(with: FixtureCatalog.personalize(template, for: video)) as? [String: Any])
        #expect(json["duration"] as? Int == 2104)
        #expect(json["thumbnailUrl"] as? String == "https://t/old.jpg")
        #expect(FixtureCatalog.personalize(Data("junk".utf8), for: video) == Data("junk".utf8))
    }

    @Test func protocolPersonalizesStreamsRequestsOnly() {
        let original = FixtureURLProtocol.loader
        defer { FixtureURLProtocol.loader = original }
        FixtureURLProtocol.loader = { name in name == "search" ? self.search : (name == "streams" ? self.template : nil) }
        let streams = FixtureURLProtocol.personalized(template, for: URL(string: "https://x/streams/abc")!)
        #expect(String(decoding: streams, as: UTF8.self).contains("\"First\""))
        let unknown = FixtureURLProtocol.personalized(template, for: URL(string: "https://x/streams/zzz")!)
        #expect(unknown == template)
        #expect(FixtureURLProtocol.personalized(search, for: URL(string: "https://x/search?q=a")!) == search)
    }

    @Test func bundledFixturesCoverTheFirstSearchResult() throws {
        // The acceptance suite plays the first search result and asserts its
        // own title in the mini player; that only holds if the catalog knows it.
        let bundle = Bundle(for: PlayerState.self)  // the app bundle carries Fixtures/
        let search = try #require(bundle.url(forResource: "search", withExtension: "json")
                                  ?? bundle.url(forResource: "search", withExtension: "json", subdirectory: "Fixtures"))
        let first = try #require(FixtureCatalog.videos(in: Data(contentsOf: search)).first)
        #expect(first.title == "Guess What Age Punched You")
    }
}
