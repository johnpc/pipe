import Testing
import Foundation
@testable import pipe

struct HLSPlaylistLoaderTests {
    private let loader = HLSPlaylistLoader(playlists: ["master": "#EXTM3U\nmaster", "video": "#EXTM3U\nvideo"])

    @Test func servesOnlyItsOwnPlaylists() {
        #expect(loader.playlist(for: HLSPlaylist.url("video")) == Data("#EXTM3U\nvideo".utf8))
        #expect(loader.playlist(for: HLSPlaylist.url("audio")) == nil)
        #expect(loader.playlist(for: URL(string: "https://master/index.m3u8")) == nil)
        #expect(loader.playlist(for: nil) == nil)
    }

    @Test func slicesTheRequestedRange() {
        let body = Data("0123456789".utf8)
        #expect(HLSPlaylistLoader.slice(body, offset: 0, length: -1) == body)
        #expect(HLSPlaylistLoader.slice(body, offset: 2, length: 3) == Data("234".utf8))
        #expect(HLSPlaylistLoader.slice(body, offset: 8, length: 10) == Data("89".utf8))
        #expect(HLSPlaylistLoader.slice(body, offset: 50, length: 2).isEmpty)
        #expect(HLSPlaylistLoader.slice(body, offset: -5, length: 2) == Data("01".utf8))
    }
}
