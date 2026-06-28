import SwiftUI

/// "Up Next" — related videos shown under a video's detail. Tapping a row plays
/// it; the context menu offers Play Next / Add to Queue.
struct RelatedVideosView: View {
    let related: [RelatedStream]
    @ObservedObject var player: PlayerState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up Next").font(.headline)
            ForEach(related) { v in
                VideoRow(v: v,
                         onPlay: { run(v, .play) },
                         onQueue: { run(v, .queue) },
                         onPlayNext: { run(v, .playNext) })
                    .accessibilityIdentifier("relatedRow")
            }
        }
    }

    private func run(_ v: RelatedStream, _ action: Playback.Action) {
        Task { await Playback.run(videoId: v.videoId, action: action, player: player) }
    }
}
