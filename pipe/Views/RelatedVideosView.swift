import SwiftUI

/// "Up Next" — related videos shown under a video's detail. Tapping a row plays
/// it; the context menu offers Play Next / Add to Queue.
struct RelatedVideosView: View {
    let related: [RelatedStream]
    @ObservedObject var player: PlayerState
    /// Inside a navigation stack (the detail page) rows push their own detail
    /// page, with the chevron every other list row has. In the player sheet
    /// there is no stack, so rows are plain.
    var navigable: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Up Next").font(.headline)
            ForEach(related) { v in
                if navigable {
                    NavigationLink(value: v) { row(v) }
                } else {
                    row(v)
                }
            }
        }
    }

    private func row(_ v: RelatedStream) -> some View {
        VideoRow(v: v,
                 onPlay: { run(v, .play) },
                 onQueue: { run(v, .queue) },
                 onPlayNext: { run(v, .playNext) },
                 onCast: { Playback.cast(videoId: v.videoId, player: player) })
            .accessibilityIdentifier("relatedRow")
    }

    private func run(_ v: RelatedStream, _ action: Playback.Action) {
        Playback.perform(QueueItem(pending: v), action: action, player: player)
    }
}
