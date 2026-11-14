import Foundation

/// Fetches a YouTube HLS master playlist and picks the audio-only playlist to
/// play in audio mode, so the player never downloads video frames just to
/// listen. (A media playlist is playable by AVPlayer on its own.)
enum HLSMasterLoader {
    static func load(_ master: URL, session: URLSession = .shared) async throws -> HLSMaster {
        let (data, response) = try await session.data(from: master)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return HLSMaster.parse(String(decoding: data, as: UTF8.self), relativeTo: master)
    }

    /// The audio rendition playlist for `preferred`, or nil when the master
    /// can't be read or offers no audio renditions (caller plays the master).
    static func audioPlaylist(master: URL, preferred: String, session: URLSession = .shared) async -> URL? {
        guard let parsed = try? await load(master, session: session) else { return nil }
        return parsed.audioRendition(preferred: preferred)?.uri
    }
}
