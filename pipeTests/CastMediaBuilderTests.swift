import Testing
import Foundation
@testable import pipe

// Only compiles/runs when the Google Cast SDK is linked (locally + CI, once the
// GoogleCast.xcframework is present). Guards the translation from our pure
// CastMedia into the SDK's GCKMediaInformation — a wrong URL, MIME, or missing
// title here would silently send the TV the wrong thing.
#if canImport(GoogleCast)
import GoogleCast

@MainActor
struct CastMediaBuilderTests {

    private func media(url: String = "https://rr5.googlevideo.com/v.mp4") -> CastMedia {
        CastLogic.media(url: url, title: "Big Buck Bunny", artist: "Blender", thumbnail: "https://x/thumb.jpg", startTime: 12)
    }

    @Test func mapsUrlAndContentType() {
        let info = CastMediaBuilder.info(from: media())
        #expect(info.contentURL?.absoluteString == "https://rr5.googlevideo.com/v.mp4")
        #expect(info.contentType == "video/mp4")
        #expect(info.streamType == .buffered)
    }

    @Test func mapsTitleAndArtistIntoMetadata() {
        let info = CastMediaBuilder.info(from: media())
        #expect(info.metadata?.string(forKey: kGCKMetadataKeyTitle) == "Big Buck Bunny")
        #expect(info.metadata?.string(forKey: kGCKMetadataKeySubtitle) == "Blender")
    }

    @Test func attachesThumbnailImageWhenValid() {
        let info = CastMediaBuilder.info(from: media())
        #expect(info.metadata?.images().isEmpty == false)
    }

    @Test func skipsThumbnailWhenEmpty() {
        let m = CastLogic.media(url: "https://x/v.mp4", title: "T", artist: "A", thumbnail: "", startTime: 0)
        let info = CastMediaBuilder.info(from: m)
        // An empty thumbnail string yields no image rather than a bogus one.
        #expect(info.metadata?.images().isEmpty == true)
    }
}
#endif
