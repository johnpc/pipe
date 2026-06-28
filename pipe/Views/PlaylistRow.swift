import SwiftUI

/// A single playlist reference row: thumbnail, name, uploader, and video count.
struct PlaylistRow: View {
    let item: PlaylistItem

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncImage(url: URL(string: item.displayThumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                    .frame(width: 100, height: 56).clipped().cornerRadius(6)
                Image(systemName: "square.stack.fill")
                    .font(.caption2).foregroundColor(.white)
                    .padding(4).background(.black.opacity(0.7)).cornerRadius(4).padding(4)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).font(.subheadline).lineLimit(2)
                if let uploader = item.uploaderName, !uploader.isEmpty {
                    Text(uploader).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                if let count = item.videoCountText {
                    Text(count).font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
