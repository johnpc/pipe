import Foundation

/// Pure, injectable formatting for the `uploadedDate` strings Piped hands us.
/// Three shapes arrive: ISO8601 (`2009-10-25T00:00:00.000Z`, from the shim),
/// a UTC wall clock for scheduled premieres/livestreams (`2026-11-25 20:00`),
/// and already-human text (`3 weeks ago`). The scheduled form is the one that
/// used to leak through raw: it is UTC and 24-hour, so it read as the wrong
/// time. It becomes "Today at 3 PM ET" in the viewer's own zone.
enum UploadDateFormat {
    static func string(_ raw: String, now: Date = Date(), timeZone: TimeZone = .current,
                       locale: Locale = .current) -> String {
        if let date = scheduledDate(raw) {
            return scheduled(date, now: now, timeZone: timeZone, locale: locale)
        }
        if let date = isoDate(raw) {
            relative.locale = locale
            return relative.localizedString(for: date, relativeTo: now)
        }
        return raw
    }

    /// "Today at 3 PM ET", "Tomorrow at 8:30 PM ET", "Wed at 8 PM ET", "Dec 4 at 8 PM ET".
    static func scheduled(_ date: Date, now: Date, timeZone: TimeZone, locale: Locale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        return "\(dayWord(date, now: now, calendar: calendar)) at \(clock(date, timeZone: timeZone, locale: locale))"
    }

    static func dayWord(_ date: Date, now: Date, calendar: Calendar) -> String {
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: date)).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        default: break
        }
        var style = Date.FormatStyle(locale: calendar.locale ?? .current, calendar: calendar,
                                     timeZone: calendar.timeZone)
        style = (2...6).contains(days) ? style.weekday(.abbreviated) : style.month(.abbreviated).day()
        return date.formatted(style)
    }

    /// "3pm ET" on the hour, "8:30pm ET" otherwise. Built by hand so the
    /// output is exactly this (12-hour, no narrow no-break space before am/pm)
    /// regardless of the device's 24-hour setting; the zone name is localized.
    static func clock(_ date: Date, timeZone: TimeZone, locale: Locale) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour24 = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let minutes = minute == 0 ? "" : String(format: ":%02d", minute)
        let zone = date.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).timeZone(.genericName(.short)))
        return "\(hour12)\(minutes)\(hour24 < 12 ? "am" : "pm") \(zone)"
    }

    static func isoDate(_ raw: String) -> Date? {
        isoFractional.date(from: raw) ?? isoPlain.date(from: raw)
    }

    /// Piped's premiere/livestream `uploadedDate` is a UTC wall clock: search
    /// sends `yyyy-MM-dd HH:mm`, a channel's video list sends `dd/MM/yyyy, HH:mm`.
    static func scheduledDate(_ raw: String) -> Date? {
        guard raw.count >= 16, raw.first?.isNumber == true else { return nil }  // cheap reject: "3 weeks ago"
        return scheduledFormatters.lazy.compactMap { $0.date(from: raw) }.first
    }

    // Formatters are costly to build and rows call these on every render while
    // scrolling, so each is built once. Only ever used from the main thread.
    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    private static let isoPlain = ISO8601DateFormatter()
    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
    private static let scheduledFormatters: [DateFormatter] = ["yyyy-MM-dd HH:mm", "dd/MM/yyyy, HH:mm"].map {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = $0
        return formatter
    }
}
