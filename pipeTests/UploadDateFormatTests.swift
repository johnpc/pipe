import Testing
import Foundation
@testable import pipe

/// Fixed clock: Wed 2026-11-25 10:00 ET (15:00Z). Eastern is UTC-5 in November.
struct UploadDateFormatTests {
    private let eastern = TimeZone(identifier: "America/New_York")!
    private let locale = Locale(identifier: "en_US")
    private let now = Date(timeIntervalSince1970: 1_795_618_800)  // 2026-11-25T15:00:00Z

    private func format(_ raw: String) -> String {
        UploadDateFormat.string(raw, now: now, timeZone: eastern, locale: locale)
    }

    @Test func scheduledTodayIsLocalTwelveHour() {
        // Piped's premiere string is UTC wall-clock, 24-hour: 20:00Z is 3 PM Eastern.
        #expect(format("2026-11-25 20:00") == "Today at 3pm ET")
    }

    @Test func scheduledKeepsMinutesWhenNotOnTheHour() {
        #expect(format("2026-11-25 20:30") == "Today at 3:30pm ET")
    }

    @Test func scheduledTomorrowCrossesMidnightInLocalZone() {
        // 01:00Z on the 26th is still the 25th at 8 PM Eastern, so "Today".
        #expect(format("2026-11-26 01:00") == "Today at 8pm ET")
        #expect(format("2026-11-26 23:00") == "Tomorrow at 6pm ET")
    }

    @Test func scheduledYesterdayAndWeekdayAndDate() {
        #expect(format("2026-11-24 20:00") == "Yesterday at 3pm ET")
        #expect(format("2026-11-28 20:00") == "Sat at 3pm ET")
        #expect(format("2026-12-04 20:00") == "Dec 4 at 3pm ET")
    }

    @Test func channelListDayFirstScheduledForm() {
        // A channel's video list sends the premiere time day-first (Money Guy, Nov 26).
        #expect(format("25/11/2026, 20:00") == "Today at 3pm ET")
        #expect(UploadDateFormat.scheduledDate("27/11/2026, 14:00") == Date(timeIntervalSince1970: 1_795_788_000))
        #expect(UploadDateFormat.scheduledDate("3 weeks ago") == nil)
    }

    @Test func isoDateStaysRelative() {
        #expect(format("2009-10-25T00:00:00.000Z") == "17 years ago")
        #expect(format("2026-11-25T00:00:00Z") == "15 hours ago")
    }

    @Test func humanTextPassesThrough() {
        #expect(format("3 weeks ago") == "3 weeks ago")
        #expect(format("Streamed 3 months ago") == "Streamed 3 months ago")
    }

    @Test func otherZoneUsesItsOwnAbbreviation() {
        let pacific = TimeZone(identifier: "America/Los_Angeles")!
        let s = UploadDateFormat.string("2026-11-25 20:00", now: now, timeZone: pacific, locale: locale)
        #expect(s == "Today at 12pm PT")
    }
}
