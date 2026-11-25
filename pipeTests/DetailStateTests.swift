import Testing
import Foundation
@testable import pipe

/// Fixed clock: Wed 2026-11-25 10:00 ET (15:00Z).
struct DetailStateTests {
    private let now = Date(timeIntervalSince1970: 1_795_618_800)
    private let premiere = DetailPreview(title: "Soon", uploader: "U", thumbnail: "t", duration: -1, uploadedDate: "2026-11-25 20:00")
    private let video = DetailPreview(title: "Vid", uploader: "U", thumbnail: "t", duration: 600, uploadedDate: "3 weeks ago")

    private func stream() -> StreamResponse {
        StreamResponse(title: "t", description: nil, uploader: "u", uploaderUrl: nil, duration: 1, hls: nil, audioStreams: [], videoStreams: [], thumbnailUrl: "", uploadDate: nil, chapters: nil, relatedStreams: nil)
    }

    @Test func previewsComeFromEveryRowShape() {
        let related = RelatedStream(url: "/watch?v=a", title: "A", thumbnail: "ta", duration: -1, uploaderName: "Chan", uploadedDate: "2099-01-01 20:00", uploaded: nil)
        #expect(DetailPreview(related) == DetailPreview(title: "A", uploader: "Chan", thumbnail: "ta", duration: -1, uploadedDate: "2099-01-01 20:00"))
        let item = SearchItem(url: "/watch?v=b", type: "stream", title: "B", thumbnail: nil, uploaderName: nil, uploaderUrl: nil, duration: nil, name: nil, uploadedDate: nil, verified: nil, subscribers: nil, videos: nil)
        #expect(DetailPreview(item) == DetailPreview(title: "B", uploader: "", thumbnail: "", duration: 0, uploadedDate: nil))
        let recent = RecentItem(videoId: "c", title: "C", artist: "Art", thumbnail: "tc", timestamp: 5, lastWatched: now, duration: 90, uploadedDate: "1 day ago")
        #expect(DetailPreview(recent) == DetailPreview(title: "C", uploader: "Art", thumbnail: "tc", duration: 90, uploadedDate: "1 day ago"))
        #expect(DetailPreview(related).status(now: now) == .upcoming(Date(timeIntervalSince1970: 4_070_980_800)))
    }

    @Test func successIsLoadedEvenForAStalePremierePreview() {
        #expect(DetailLoadLogic.state(.success(stream()), preview: premiere, now: now) == .loaded(stream()))
    }

    @Test func failureOnAKnownPremiereIsUpcomingWithItsStart() {
        let start = Date(timeIntervalSince1970: 1_795_636_800)
        #expect(DetailLoadLogic.state(.failure(URLError(.notConnectedToInternet)), preview: premiere, now: now)
                == .upcoming(start: start, message: nil))
        let piped = PipedError(message: #"Got error LIVE_STREAM_OFFLINE: "This live event will begin in 6 hours.""#)
        #expect(DetailLoadLogic.state(.failure(piped), preview: premiere, now: now)
                == .upcoming(start: start, message: "This live event will begin in 6 hours."))
    }

    @Test func instanceWordingDecidesWhenTheRowKnewNothing() {
        let live = PipedError(message: "ERROR: [youtube] 5mO0ZKuJwN8: This live event will begin in 6 hours.")
        #expect(DetailLoadLogic.state(.failure(live), preview: nil, now: now) == .upcoming(start: nil, message: "This live event will begin in 6 hours."))
        let gone = PipedError(message: "ERROR: [youtube] aaaaaaaaaaa: This video is unavailable")
        #expect(DetailLoadLogic.state(.failure(gone), preview: video, now: now) == .unavailable("This video is unavailable"))
        #expect(DetailLoadLogic.state(.failure(PipedError(message: "Private video. Sign in if you've been granted access")), preview: nil, now: now)
                == .unavailable("Private video. Sign in if you've been granted access"))
        #expect(DetailLoadLogic.state(.failure(PipedError(message: "Join this channel to get access to members-only content")), preview: nil, now: now)
                == .unavailable("Join this channel to get access to members-only content"))
    }

    @Test func deepLinkPremiereUsesTheInstanceSchedule() {
        let start = Date(timeIntervalSince1970: 1_795_647_600)
        let refused = PipedError(message: "This live event will begin in 5 hours.",
                                 schedule: PremiereSchedule(start: start, title: "Late Edition", uploader: "GBNews", thumbnail: "th"))
        #expect(DetailLoadLogic.state(.failure(refused), preview: nil, now: now) == .upcoming(start: start, message: "This live event will begin in 5 hours."))
        #expect(DetailLoadLogic.preview(for: refused, fallback: nil) == DetailPreview(title: "Late Edition", uploader: "GBNews", thumbnail: "th", duration: -1, uploadedDate: nil))
        #expect(DetailLoadLogic.preview(for: refused, fallback: video) == video)
        #expect(DetailLoadLogic.preview(for: URLError(.timedOut), fallback: nil) == nil)
        // The row's own schedule wins over the instance's when both exist.
        #expect(DetailLoadLogic.state(.failure(refused), preview: premiere, now: now) == .upcoming(start: Date(timeIntervalSince1970: 1_795_636_800), message: "This live event will begin in 5 hours."))
    }

    @Test func transientFailuresKeepTheRetryButton() {
        #expect(DetailLoadLogic.state(.failure(URLError(.timedOut)), preview: video, now: now) == .failed)
        #expect(DetailLoadLogic.state(.failure(PipedError(message: "JSON response is too short")), preview: nil, now: now) == .failed)
        #expect(DetailLoadLogic.state(.failure(PipedError.http(502)), preview: nil, now: now) == .failed)
    }

    @Test func humanMessageStripsExtractorFraming() {
        #expect(DetailLoadLogic.humanMessage("ERROR: [youtube] abc-123_XY: This video is unavailable") == "This video is unavailable")
        #expect(DetailLoadLogic.humanMessage("org.schabi...ContentNotAvailableException: Got error LIVE_STREAM_OFFLINE: \"This live event will begin in 6 hours.\"\n\tat org.schabi") == "This live event will begin in 6 hours.")
        #expect(DetailLoadLogic.humanMessage("plain words") == "plain words")
    }
}
