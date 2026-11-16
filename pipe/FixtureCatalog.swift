import Foundation

/// A video the bundled fixtures know about: enough to answer `/streams/<id>`
/// with that video's own identity instead of one video for every id.
struct FixtureVideo: Equatable {
    let videoId: String
    let title: String
    let uploader: String
    let duration: Int
    let thumbnail: String
}

/// Reads videos out of any Piped-shaped fixture (search results, trending,
/// channel pages, channel tabs, playlists, a stream's related list) and
/// personalizes the one `streams.json` template for a given id. Pure, so the
/// per-id mock is unit-tested without the app bundle.
enum FixtureCatalog {
    /// Fixture names whose rows feed the catalog, in lookup order.
    static let sources = ["search", "trending", "channel", "channelTab", "playlist", "streams"]

    /// "/watch?v=abc" → "abc"; nil for channels, playlists, and anything else.
    static func videoId(fromWatchURL url: String) -> String? {
        guard let range = url.range(of: "/watch?v=") else { return nil }
        let id = url[range.upperBound...].split(separator: "&").first.map(String.init) ?? ""
        return id.isEmpty ? nil : id
    }

    /// "/streams/abc" → "abc".
    static func videoId(fromStreamsPath path: String) -> String? {
        guard path.hasPrefix("/streams/") else { return nil }
        let id = String(path.dropFirst("/streams/".count))
        return id.isEmpty ? nil : id
    }

    /// Every video row in a fixture, wherever Piped puts them: a top-level
    /// array (trending), `items` (search), `relatedStreams` (channel, playlist,
    /// streams), or `content` (channel tabs). Rows without a watch URL or title
    /// (channels, malformed mixes) are skipped.
    static func videos(in data: Data) -> [FixtureVideo] {
        guard let json = try? JSONSerialization.jsonObject(with: data) else { return [] }
        let rows: [Any]
        if let array = json as? [Any] {
            rows = array
        } else if let object = json as? [String: Any] {
            rows = (object["items"] ?? object["relatedStreams"] ?? object["content"]) as? [Any] ?? []
        } else {
            return []
        }
        return rows.compactMap { row in
            guard let fields = row as? [String: Any],
                  let url = fields["url"] as? String, let id = videoId(fromWatchURL: url),
                  let title = fields["title"] as? String else { return nil }
            return FixtureVideo(videoId: id, title: title, uploader: fields["uploaderName"] as? String ?? "",
                                duration: fields["duration"] as? Int ?? 0, thumbnail: fields["thumbnail"] as? String ?? "")
        }
    }

    /// First match for `id` across the sources, loading each via `loader`.
    static func video(_ id: String, loader: (String) -> Data?) -> FixtureVideo? {
        for name in sources {
            if let data = loader(name), let hit = videos(in: data).first(where: { $0.videoId == id }) { return hit }
        }
        return nil
    }

    /// The streams template rewritten to describe `video`: title, uploader,
    /// duration, and thumbnail. Streams, chapters, and related videos are kept,
    /// so every id plays "the same media" but is recognizably itself.
    static func personalize(_ template: Data, for video: FixtureVideo) -> Data {
        guard var object = (try? JSONSerialization.jsonObject(with: template)) as? [String: Any] else { return template }
        object["title"] = video.title
        object["uploader"] = video.uploader
        if video.duration > 0 { object["duration"] = video.duration }
        if !video.thumbnail.isEmpty { object["thumbnailUrl"] = video.thumbnail }
        return (try? JSONSerialization.data(withJSONObject: object)) ?? template
    }
}
