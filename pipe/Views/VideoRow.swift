import SwiftUI

struct TabPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

struct VideoRow: View {
    let v: RelatedStream
    var isCompleted: Bool = false
    var resumeTime: Double? = nil
    let onPlay: () -> Void
    let onQueue: () -> Void
    var isSaved: Bool = false
    var onToggleSave: (() -> Void)? = nil
    var isDownloaded: Bool = false
    var onToggleDownload: (() -> Void)? = nil

    var body: some View {
        content
            .contextMenu {
                mediaContextMenu(videoId: v.videoId, onPlay: onPlay, onQueue: onQueue,
                                 isSaved: isSaved, onToggleSave: onToggleSave,
                                 isDownloaded: isDownloaded, onToggleDownload: onToggleDownload)
            }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: v.thumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                        .frame(width: 100, height: 56).clipped().cornerRadius(6)
                        .overlay(isCompleted ? Color.black.opacity(0.4).cornerRadius(6) : nil)
                    HStack(spacing: 4) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        if v.duration > 0 {
                            Text(formatDuration(v.duration))
                                .font(.caption2).bold()
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(4)
                }

                VStack(alignment: .leading, spacing: 2) {
                    if let uploader = v.uploaderName {
                        Text(uploader).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                    }
                    if let date = v.uploadedDate {
                        Text(formatUploadDate(date)).font(.caption2).foregroundStyle(.tertiary)
                    }
                    if let time = resumeTime {
                        Label(formatTime(time), systemImage: "play.circle").font(.caption2).foregroundColor(.orange)
                    }
                }

                Spacer()

                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill").font(.title2)
                }.buttonStyle(.plain).accessibilityIdentifier("playButton").accessibilityLabel("Play")
                Button(action: onQueue) {
                    Image(systemName: "text.badge.plus").font(.title3)
                }.buttonStyle(.plain).accessibilityIdentifier("queueButton").accessibilityLabel("Add to queue")
            }

            Text(v.title).font(.subheadline).lineLimit(3)
        }
        .padding(.vertical, 8)
    }
}
