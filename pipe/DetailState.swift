import Foundation

/// What a list row already knows about a video, carried into its detail page so
/// the page can show the title, channel, and thumbnail — and say when a premiere
/// starts — even when the instance has no stream data for it yet.
struct DetailPreview: Equatable, Hashable {
    let title: String
    let uploader: String
    let thumbnail: String
    let duration: Int
    let uploadedDate: String?

    func status(now: Date = Date()) -> StreamStatus { StreamStatus.of(duration: duration, uploadedDate: uploadedDate, now: now) }

    init(title: String, uploader: String, thumbnail: String, duration: Int, uploadedDate: String?) {
        self.title = title; self.uploader = uploader; self.thumbnail = thumbnail
        self.duration = duration; self.uploadedDate = uploadedDate
    }
    init(_ v: RelatedStream) {
        self.init(title: v.title, uploader: v.uploaderName ?? "", thumbnail: v.thumbnail, duration: v.duration, uploadedDate: v.uploadedDate)
    }
    init(_ item: SearchItem) {
        self.init(title: item.displayTitle, uploader: item.displayUploader, thumbnail: item.displayThumbnail,
                  duration: item.duration ?? 0, uploadedDate: item.uploadedDate)
    }
    init(_ item: RecentItem) {
        self.init(title: item.title, uploader: item.artist, thumbnail: item.thumbnail, duration: item.duration, uploadedDate: item.uploadedDate)
    }
}

/// The detail page's state. Beyond load/fail it tells apart the two reasons a
/// video has no stream that are NOT worth a Retry button: it has not started
/// yet (premiere / scheduled stream) and it is not available at all (private,
/// removed, region- or age-locked, members-only).
enum DetailState: Equatable {
    case loading
    case loaded(StreamResponse)
    /// `start` is known when the row carried the schedule; `message` is the
    /// instance's own wording ("This live event will begin in 6 hours.").
    case upcoming(start: Date?, message: String?)
    case unavailable(String)
    /// Transient: network, instance down, extractor hiccup — offer Retry.
    case failed
}

/// Pure classification of a `/streams` outcome into a `DetailState`.
enum DetailLoadLogic {
    static func state(_ result: Result<StreamResponse, Error>, preview: DetailPreview?, now: Date = Date()) -> DetailState {
        switch result {
        case .success(let stream):
            return .loaded(stream)
        case .failure(let error):
            let message = (error as? PipedError).map { humanMessage($0.message) }
            if case .upcoming(let start)? = preview?.status(now: now) { return .upcoming(start: start, message: message) }
            guard let message else { return .failed }
            switch reason(message) {
            case .upcoming: return .upcoming(start: nil, message: message)
            case .unavailable: return .unavailable(message)
            case nil: return .failed
            }
        }
    }

    enum Reason { case upcoming, unavailable }

    /// YouTube's playability wording, as relayed by yt-dlp or NewPipe.
    static func reason(_ message: String) -> Reason? {
        let text = message.lowercased()
        if ["live event will begin", "premieres in", "premiere will begin", "live_stream_offline", "will begin in"].contains(where: text.contains) {
            return .upcoming
        }
        let unavailable = ["unavailable", "private video", "is private", "not available in your country", "has been removed",
                           "terminated", "members-only", "members only", "join this channel", "confirm your age",
                           "age-restricted", "age restricted", "contentnotavailable", "blocked it in your country"]
        return unavailable.contains(where: text.contains) ? .unavailable : nil
    }

    /// Strip extractor framing so the viewer reads the sentence, not the plumbing:
    /// `ERROR: [youtube] abc123: This video is unavailable` → `This video is unavailable`,
    /// `Got error LIVE_STREAM_OFFLINE: "This live event will begin in 6 hours."` → the quoted part.
    static func humanMessage(_ raw: String) -> String {
        var text = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? raw
        if let open = text.firstIndex(of: "\""), let close = text.lastIndex(of: "\""), open < close {
            text = String(text[text.index(after: open)..<close])
        }
        if let range = text.range(of: #"^ERROR: \[[^\]]+\] [^:]+: "#, options: .regularExpression) {
            text = String(text[range.upperBound...])
        }
        return text.trimmingCharacters(in: .whitespaces)
    }
}
