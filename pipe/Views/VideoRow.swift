import SwiftUI

struct VideoRow: View {
    let v: RelatedStream
    var isCompleted: Bool = false
    var resumeTime: Double? = nil
    let onPlay: () -> Void
    let onQueue: () -> Void
    var onPlayNext: (() -> Void)? = nil
    var onCast: (() -> Void)? = nil
    var isSaved: Bool = false
    var onToggleSave: (() -> Void)? = nil
    var isDownloaded: Bool = false
    var onToggleDownload: (() -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var m: RowMetrics { RowMetrics.forSizeClass(sizeClass) }
    private var status: StreamStatus { StreamStatus.of(duration: v.duration, uploadedDate: v.uploadedDate, isShort: v.isShort) }

    var body: some View {
        if status.isPlayable {
            content.contextMenu {
                mediaContextMenu(videoId: v.videoId, onPlay: onPlay, onQueue: onQueue,
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
                    AsyncImage(url: URL(string: v.thumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                        .frame(width: m.thumbWidth, height: m.thumbHeight).clipped().cornerRadius(6)
                        .overlay(isCompleted ? Color.black.opacity(0.4).cornerRadius(6) : nil)
                    ThumbnailBadge(status: status, duration: v.duration, isCompleted: isCompleted)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let uploader = v.uploaderName {
                        Text(uploader).font(m.metaFont).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                    }
                    if m.titleBesideArt {
                        Text(v.title).font(m.titleFont).lineLimit(2)
                    }
                    if let caption = status.caption(uploadedDate: v.uploadedDate) {
                        Text(caption).font(m.captionFont).foregroundStyle(status == .live ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
                    }
                    if let time = resumeTime {
                        Label(formatTime(time), systemImage: "play.circle").font(.caption2).foregroundColor(.orange)
                    }
                }

                Spacer()

                RowPlayButtons(onPlay: status.isPlayable ? onPlay : nil, onQueue: status.isPlayable ? onQueue : nil)
            }

            if !m.titleBesideArt {
                Text(v.title).font(m.titleFont).lineLimit(3)
            }
        }
        .padding(.vertical, m.rowPadding)
    }
}
