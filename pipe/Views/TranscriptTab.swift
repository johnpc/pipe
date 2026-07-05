import SwiftUI

/// The Full Player's "Transcript" tab: the now-playing video's captions, each
/// tappable to seek, plus an optional Apple Intelligence summary streamed in at
/// the top. Loads from the stream's subtitle tracks on appear / track change.
struct TranscriptTab: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var detail: NowPlayingDetail
    @StateObject private var store: TranscriptStore

    init(player: PlayerState, detail: NowPlayingDetail, store: TranscriptStore? = nil) {
        self.player = player
        self.detail = detail
        _store = StateObject(wrappedValue: store ?? TranscriptStore())
    }

    var body: some View {
        content
            .task(id: player.currentVideoId) {
                await store.load(subtitles: detail.state.value?.subtitles,
                                 videoId: player.currentVideoId)
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .loaded(let cues):
            VStack(alignment: .leading, spacing: 12) {
                summarySection
                ForEach(cues) { cue in
                    Button { player.seek(to: cue.start) } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text(formatTime(cue.start))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 52, alignment: .leading)
                            Text(cue.text).font(.subheadline)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("transcriptRow")
                }
            }
        case .loading:
            ProgressView().padding()
        case .failed:
            ContentUnavailableView("No transcript available", systemImage: "captions.bubble")
                .frame(minHeight: 200)
        }
    }

    @ViewBuilder
    private var summarySection: some View {
        if !store.summary.isEmpty {
            Text(store.summary)
                .font(.callout)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondary.opacity(0.12))
                .cornerRadius(12)
        }
        if store.canSummarize {
            Button { store.summarize() } label: {
                Label(store.isSummarizing ? "Summarizing…" : "Summarize with Apple Intelligence",
                      systemImage: "apple.intelligence")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isSummarizing)
            .accessibilityIdentifier("summarizeButton")
            Divider()
        }
    }
}
