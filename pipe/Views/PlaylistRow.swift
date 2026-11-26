import SwiftUI

/// A single playlist reference row: thumbnail, name, uploader, and video count.
struct PlaylistRow: View {
    let item: PlaylistItem
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var m: RowMetrics { RowMetrics.forSizeClass(sizeClass) }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: item.displayThumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                    .frame(width: m.thumbWidth, height: m.thumbHeight).clipped().cornerRadius(6)
                Image(systemName: "square.stack.fill")
                    .font(.caption2).foregroundColor(.white)
                    .padding(4).background(.black.opacity(0.7)).cornerRadius(4).padding(4)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).font(m.titleFont).lineLimit(2)
                if let uploader = item.uploaderName, !uploader.isEmpty {
                    Text(uploader).font(m.metaFont).foregroundStyle(.secondary).lineLimit(1)
                }
                if let count = item.videoCountText {
                    Text(count).font(m.captionFont).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
