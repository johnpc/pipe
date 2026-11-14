import Testing
import Foundation
@testable import pipe

/// Fetching the master and picking the audio playlist. Nested under the
/// index-loader suite because both drive the static `RangeServingURLProtocol`;
/// the parent's `.serialized` trait applies recursively, so they never overlap.
extension MP4SegmentIndexLoaderTests {
@Suite(.serialized)
struct HLSMasterLoaderTests {
    private let master = URL(string: "https://manifest.example/master.m3u8")!

    @Test func returnsTheChosenRenditionPlaylist() async {
        let session = RangeServingURLProtocol.makeSession(serving: Data(HLSMasterTests.text.utf8), status: 200)
        let url = await HLSMasterLoader.audioPlaylist(master: master, preferred: "es", session: session)
        #expect(url?.absoluteString == "https://manifest.example/234/es.m3u8")
    }

    @Test func nilWhenTheMasterCannotBeFetchedOrHasNoAudio() async {
        let denied = RangeServingURLProtocol.makeSession(serving: Data(), status: 403)
        #expect(await HLSMasterLoader.audioPlaylist(master: master, preferred: "en", session: denied) == nil)
        let videoOnly = RangeServingURLProtocol.makeSession(serving: Data("#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=1\nv.m3u8\n".utf8), status: 200)
        #expect(await HLSMasterLoader.audioPlaylist(master: master, preferred: "en", session: videoOnly) == nil)
    }
}
}
