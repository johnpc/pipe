import Foundation
import Combine

/// Loads the now-playing video's transcript (from a Piped subtitle track) and,
/// on demand, an Apple Intelligence summary of it. Keyed by video id so it
/// reloads when the track changes. Dependencies are injectable for testing.
@MainActor
final class TranscriptStore: ObservableObject {
    @Published private(set) var state: LoadState<[TranscriptCue]> = .loading
    /// The Apple Intelligence summary's own lifecycle.
    @Published private(set) var summaryState: SummaryState = .idle
    /// Text to show for the summary (partial while streaming); empty when idle.
    var summary: String { summaryState.text }
    var isSummarizing: Bool { if case .summarizing = summaryState { return true }; return false }

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
        summaryState = .summarizing(partial: "")
        summarizeTask = Task { [summarizer] in
            var partial = ""
            do {
                for try await snapshot in summarizer.stream(text) {
                    partial = snapshot
                    summaryState = .summarizing(partial: partial)
                }
                summaryState = .done(partial)
            } catch {
                summaryState = partial.isEmpty ? .failed("Couldn't summarize — try again.") : .done(partial)
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
        summaryState = .idle
    }
}

/// Lifecycle of the on-demand transcript summary.
enum SummaryState: Equatable {
    case idle
    case summarizing(partial: String)
    case done(String)
    /// The message to show in place of a summary.
    case failed(String)

    var text: String {
        switch self {
        case .idle: return ""
        case let .summarizing(partial): return partial
        case let .done(text), let .failed(text): return text
        }
    }
}
