import Foundation

/// Whether a listed video is a normal upload, a stream that is live right now,
/// or a premiere/stream that has not started. Piped signals these only
/// indirectly: a live item has `duration == -1` and no upload date; a scheduled
/// one carries a UTC wall clock in `uploadedDate` (see `UploadDateFormat`).
/// A Short has the live shape too (`-1`, no date) but is flagged `isShort`.
enum StreamStatus: Equatable {
    case video
    case live
    case upcoming(Date)

    static func of(duration: Int?, uploadedDate: String?, isShort: Bool? = nil, now: Date = Date()) -> StreamStatus {
        if let raw = uploadedDate, let start = UploadDateFormat.scheduledDate(raw), start > now {
            return .upcoming(start)
        }
        if isShort == true { return .video }
        return (duration ?? 0) < 0 ? .live : .video
    }

    /// Nothing to play until it airs; rows hide their play/queue controls.
    var isPlayable: Bool {
        if case .upcoming = self { return false }
        return true
    }

    /// The row's date line: "Premieres Today at 3pm ET", "Live now", or the upload date.
    func caption(uploadedDate: String?, now: Date = Date(), timeZone: TimeZone = .current,
                 locale: Locale = .current) -> String? {
        switch self {
        case .upcoming(let start):
            return "Premieres " + UploadDateFormat.scheduled(start, now: now, timeZone: timeZone, locale: locale)
        case .live:
            return "Live now"
        case .video:
            return uploadedDate.map { UploadDateFormat.string($0, now: now, timeZone: timeZone, locale: locale) }
        }
    }
}
