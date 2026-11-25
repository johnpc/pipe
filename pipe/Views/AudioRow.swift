import SwiftUI

struct AudioRow: View {
    let item: SearchItem
    var isCompleted: Bool = false
    var resumeTime: Double? = nil
    var onPlay: (() -> Void)?
    var onQueue: (() -> Void)?
    var onPlayNext: (() -> Void)? = nil
    var onCast: (() -> Void)? = nil
    var isSaved: Bool = false
    var onToggleSave: (() -> Void)? = nil
    var isDownloaded: Bool = false
    var onToggleDownload: (() -> Void)? = nil

    private var status: StreamStatus { StreamStatus.of(duration: item.duration, uploadedDate: item.uploadedDate, isShort: item.isShort) }

    var body: some View {
        if status.isPlayable {
            content.contextMenu {
                mediaContextMenu(videoId: item.videoId, onPlay: onPlay, onQueue: onQueue,
                                 onPlayNext: onPlayNext, onCast: onCast, isSaved: isSaved, onToggleSave: onToggleSave,
                                 isDownloaded: isDownloaded, onToggleDownload: status == .live ? nil : onToggleDownload)
            }
        } else {
            content  // an unaired premiere: nothing to play, queue, cast, or download yet
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: item.displayThumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                        .frame(width: 100, height: 56).clipped().cornerRadius(6)
                        .overlay(isCompleted ? Color.black.opacity(0.4).cornerRadius(6) : nil)
                    ThumbnailBadge(status: status, duration: item.duration ?? 0, isCompleted: isCompleted)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayUploader).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                    if let caption = status.caption(uploadedDate: item.uploadedDate) {
                        Text(caption).font(.caption2).foregroundStyle(status == .live ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                    }
                    if let time = resumeTime {
                        Label(formatTime(time), systemImage: "play.circle").font(.caption2).foregroundColor(.orange)
                    }
                }

                Spacer()

                RowPlayButtons(onPlay: status.isPlayable ? onPlay : nil, onQueue: status.isPlayable ? onQueue : nil)
            }

            Text(item.displayTitle).font(.subheadline).lineLimit(3)
        }
        .padding(.vertical, 8)
    }
}
