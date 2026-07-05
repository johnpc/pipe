import Foundation

/// Abstraction over the on-device summarizer so `TranscriptStore` is testable
/// without Apple Intelligence. `stream` yields progressively longer snapshots
/// of the summary (cumulative), matching the Foundation Models streaming shape.
@MainActor
protocol Summarizing {
    var isAvailable: Bool { get }
    func stream(_ text: String) -> AsyncThrowingStream<String, Error>
}

#if canImport(FoundationModels)
import FoundationModels

/// Summarizes transcript text with Apple Intelligence's on-device model. All
/// Foundation Models API is confined to this file so the rest of the app stays
/// framework-agnostic (and buildable where the framework is absent).
@MainActor
struct AppleIntelligenceSummarizer: Summarizing {
    private static let instructions = """
        You summarize video transcripts. Produce a concise summary of the key \
        points as a few short bullet points. Do not add information that isn't \
        in the transcript.
        """

    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    func stream(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let session = LanguageModelSession(instructions: Self.instructions)
            let task = Task {
                do {
                    for try await partial in session.streamResponse(to: text) {
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
#else
/// Fallback when the framework isn't available at build time: never available,
/// so the Summarize button stays hidden.
@MainActor
struct AppleIntelligenceSummarizer: Summarizing {
    var isAvailable: Bool { false }
    func stream(_ text: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
}
#endif
