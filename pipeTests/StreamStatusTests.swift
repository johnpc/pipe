import Testing
import Foundation
@testable import pipe

/// Fixed clock: Wed 2026-11-25 10:00 ET (15:00Z).
struct StreamStatusTests {
    private let now = Date(timeIntervalSince1970: 1_795_618_800)
    private let eastern = TimeZone(identifier: "America/New_York")!
    private let locale = Locale(identifier: "en_US")

    @Test func normalUploadIsAVideo() {
        #expect(StreamStatus.of(duration: 3285, uploadedDate: "8 days ago", now: now) == .video)
        #expect(StreamStatus.of(duration: nil, uploadedDate: nil, now: now) == .video)
        #expect(StreamStatus.of(duration: 0, uploadedDate: "2009-10-25T00:00:00.000Z", now: now) == .video)
    }

    @Test func liveStreamHasNoDurationAndNoDate() {
        // Piped's shape for a stream in progress (The Blue Print, Nov 25).
        #expect(StreamStatus.of(duration: -1, uploadedDate: nil, now: now) == .live)
    }

    @Test func scheduledInTheFutureIsUpcoming() {
        let start = Date(timeIntervalSince1970: 1_795_636_800)  // 20:00Z
        #expect(StreamStatus.of(duration: -1, uploadedDate: "2026-11-25 20:00", now: now) == .upcoming(start))
    }

    @Test func scheduledInThePastIsLiveOrDone() {
        // Piped keeps the premiere string for a while after it starts.
        #expect(StreamStatus.of(duration: -1, uploadedDate: "2026-11-25 14:00", now: now) == .live)
        #expect(StreamStatus.of(duration: 1800, uploadedDate: "2026-11-25 14:00", now: now) == .video)
    }

    @Test func onlyUpcomingIsUnplayable() {
        #expect(StreamStatus.video.isPlayable)
        #expect(StreamStatus.live.isPlayable)
        #expect(!StreamStatus.upcoming(now.addingTimeInterval(3600)).isPlayable)
    }

    @Test func captions() {
        let start = Date(timeIntervalSince1970: 1_795_636_800)
        #expect(StreamStatus.upcoming(start).caption(uploadedDate: "2026-11-25 20:00", now: now, timeZone: eastern, locale: locale)
                == "Premieres Today at 3pm ET")
        #expect(StreamStatus.live.caption(uploadedDate: nil, now: now, timeZone: eastern, locale: locale) == "Live now")
        #expect(StreamStatus.video.caption(uploadedDate: "3 weeks ago", now: now, timeZone: eastern, locale: locale) == "3 weeks ago")
        #expect(StreamStatus.video.caption(uploadedDate: nil, now: now, timeZone: eastern, locale: locale) == nil)
    }
}
