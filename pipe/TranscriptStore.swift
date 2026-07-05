import Foundation
import Combine

/// Loads the now-playing video's transcript (from a Piped subtitle track) and,
/// on demand, an Apple Intelligence summary of it. Keyed by video id so it
/// reloads when the track changes. Dependencies are injectable for testing.
@MainActor
final class TranscriptStore: ObservableObject {
    @Published private(set) var state: LoadState<[TranscriptCue]> = .loading
    @Published private(set) var summary: String = ""
    @Published private(set) var isSummarizing = false

    private let summarizer: Summarizing
    private let fetch: (URL) async throws -> String
    private let preferredLanguage: String
    private var loadedVideoId: String?
    private var summarizeTask: Task<Void, Never>?

    init(summarizer: Summarizing? = nil,
         preferredLanguage: String = Locale.current.language.languageCode?.identifier ?? "en",
         fetch: @escaping (URL) async throws -> String = { try await PipedAPI.rawText(from: $0) }) {
        self.summarizer = summarizer ?? AppleIntelligenceSummarizer()
        self.preferredLanguage = preferredLanguage
        self.fetch = fetch
    }

    nonisolated deinit {}

    /// Whether the Summarize button should appear (Apple Intelligence usable).
    var canSummarize: Bool { summarizer.isAvailable }

    /// Load the transcript for `videoId` from its subtitle tracks. A nil id (no
    /// playback) or no captions resolves to a failed/empty state.
    func load(subtitles: [Subtitle]?, videoId: String?) async {
        guard let videoId else { reset(); return }
        guard videoId != loadedVideoId else { return }
        loadedVideoId = videoId
        resetSummary()
        state = .loading
        guard let track = TranscriptLogic.bestTrack(from: subtitles, preferredLanguage: preferredLanguage),
              let url = URL(string: track.url) else { state = .failed; return }
        let cues = (try? await fetch(url)).map(TranscriptLogic.parseTTML) ?? []
        state = cues.isEmpty ? .failed : .loaded(cues)
    }

    /// Stream an Apple Intelligence summary of the loaded transcript.
    func summarize() {
        guard case let .loaded(cues) = state, !isSummarizing else { return }
        let text = TranscriptLogic.plainText(from: cues)
        isSummarizing = true
        summary = ""
        summarizeTask = Task { [summarizer] in
            defer { isSummarizing = false }
            do {
                for try await snapshot in summarizer.stream(text) {
                    summary = snapshot
                }
            } catch {
                if summary.isEmpty { summary = "Couldn't summarize — try again." }
            }
        }
    }

    private func reset() {
        loadedVideoId = nil
        state = .loading
        resetSummary()
    }

    private func resetSummary() {
        summarizeTask?.cancel()
        isSummarizing = false
        summary = ""
    }
}
