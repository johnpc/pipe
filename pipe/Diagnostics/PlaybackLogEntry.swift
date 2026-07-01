import Foundation

/// One structured diagnostic event. `fields` holds typed key/values (e.g.
/// videoId, reached, expected) so logs are queryable end-to-end rather than raw
/// text interspersed everywhere; `message` is a short human summary.
struct PlaybackLogEntry: Equatable {
    let time: Date
    let category: String
    let message: String
    let fields: [String: String]

    /// A single human-readable line for the on-device export, e.g.
    /// `12:03:04.120 [end] fired reached=1800 expected=3600`.
    var line: String {
        let rendered = fields
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        let suffix = rendered.isEmpty ? "" : " \(rendered)"
        return "\(PlaybackLogEntry.formatter.string(from: time)) [\(category)] \(message)\(suffix)"
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}
