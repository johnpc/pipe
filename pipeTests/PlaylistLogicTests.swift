import Testing
import Foundation
@testable import pipe

struct PlaylistLogicTests {

    // MARK: - id(fromURL:)

    @Test func extractsListIdFromQuery() {
        #expect(PlaylistLogic.id(fromURL: "/playlist?list=PLabc123") == "PLabc123")
    }

    @Test func extractsListIdFromFullURL() {
        #expect(PlaylistLogic.id(fromURL: "https://x/playlist?list=PLxyz&index=2") == "PLxyz")
    }

    @Test func stripsLeadingSlashWhenNoListParam() {
        #expect(PlaylistLogic.id(fromURL: "/PLbare") == "PLbare")
    }

    @Test func returnsBareIdUnchanged() {
        #expect(PlaylistLogic.id(fromURL: "PLbare") == "PLbare")
    }

    // MARK: - playableVideos

    @Test func keepsVideosWithIds() {
        let playlist = PlaylistResponse(name: "P", thumbnailUrl: nil, uploader: "U", relatedStreams: [
            RelatedStream(url: "/watch?v=a", title: "A", thumbnail: "t", duration: 10, uploaderName: "U", uploadedDate: nil, uploaded: nil),
            RelatedStream(url: "/watch?v=b", title: "B", thumbnail: "t", duration: 20, uploaderName: "U", uploadedDate: nil, uploaded: nil),
        ])
        #expect(PlaylistLogic.playableVideos(playlist).count == 2)
    }

    @Test func dropsEntriesWithEmptyVideoId() {
        let playlist = PlaylistResponse(name: "P", thumbnailUrl: nil, uploader: "U", relatedStreams: [
            RelatedStream(url: "", title: "broken", thumbnail: "t", duration: 0, uploaderName: nil, uploadedDate: nil, uploaded: nil),
        ])
        #expect(PlaylistLogic.playableVideos(playlist).isEmpty)
    }

    // MARK: - PlaylistItem display

    @Test func videoCountTextFormatsSingularAndPlural() {
        func item(_ n: Int?) -> PlaylistItem {
            PlaylistItem(url: "/playlist?list=P", name: "P", thumbnail: nil, uploaderName: nil, videos: n)
        }
        #expect(item(1).videoCountText == "1 video")
        #expect(item(12).videoCountText == "12 videos")
        #expect(item(0).videoCountText == nil)
        #expect(item(nil).videoCountText == nil)
    }

    @Test func playlistItemDerivesId() {
        let item = PlaylistItem(url: "/playlist?list=PLfoo", name: nil, thumbnail: nil, uploaderName: nil, videos: nil)
        #expect(item.playlistId == "PLfoo")
        #expect(item.displayName == "Playlist")
    }

    // MARK: - SearchItem playlist projection

    @Test func searchItemProjectsToPlaylist() {
        let item = SearchItem(url: "/playlist?list=PLs", type: "playlist", title: "T", thumbnail: "th", uploaderName: "U", uploaderUrl: nil, duration: nil, name: "Mix", uploadedDate: nil, verified: nil, subscribers: nil, videos: 5)
        #expect(item.isPlaylist)
        #expect(item.playlistId == "PLs")
        #expect(item.asPlaylistItem.displayName == "Mix")
        #expect(item.asPlaylistItem.videoCountText == "5 videos")
    }
}
