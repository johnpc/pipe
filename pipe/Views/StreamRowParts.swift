import SwiftUI

/// The pill in a thumbnail's corner: a watched check, then "LIVE" for a stream
/// in progress or the duration for a normal upload. An unaired premiere shows
/// nothing here (its row caption says when it starts).
struct ThumbnailBadge: View {
    let status: StreamStatus
    let duration: Int
    var isCompleted: Bool = false

    private var hasContent: Bool { isCompleted || status == .live || duration > 0 }

    var body: some View {
        if hasContent {
            HStack(spacing: 4) {
                if isCompleted {
                    Image(systemName: "checkmark.circle.fill").font(.caption2).foregroundColor(.white)
                }
                if status == .live {
                    Text("LIVE").font(.caption2).bold().foregroundColor(.white).accessibilityIdentifier("liveBadge")
                } else if duration > 0 {
                    Text(formatDuration(duration)).font(.caption2).bold().foregroundColor(.white)
                }
            }
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(status == .live ? Color.red.opacity(0.9) : Color.black.opacity(0.7))
            .cornerRadius(4)
            .padding(4)
        }
    }
}

/// The play and add-to-queue controls at a row's trailing edge. Rows pass nil
/// for both when the item is an unaired premiere: there is nothing to play.
struct RowPlayButtons: View {
    var onPlay: (() -> Void)?
    var onQueue: (() -> Void)?

    var body: some View {
        if let onPlay {
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill").font(.title2)
            }.buttonStyle(.plain).accessibilityIdentifier("playButton").accessibilityLabel("Play")
        }
        if let onQueue {
            Button(action: onQueue) {
                Image(systemName: "text.badge.plus").font(.title3)
            }.buttonStyle(.plain).accessibilityIdentifier("queueButton").accessibilityLabel("Add to queue")
        }
    }
}
