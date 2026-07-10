import SwiftUI

/// The shared long-press context menu for a media row: Play, Add to Queue,
/// optional Save and Download toggles, and Share. Extracted so VideoRow and
/// AudioRow stay declarative and under the view line limit, and so the menu
/// stays consistent across the app.
@ViewBuilder
func mediaContextMenu(
    videoId: String,
    onPlay: (() -> Void)?,
    onQueue: (() -> Void)?,
    onPlayNext: (() -> Void)? = nil,
    onCast: (() -> Void)? = nil,
    isSaved: Bool,
    onToggleSave: (() -> Void)?,
    isDownloaded: Bool,
    onToggleDownload: (() -> Void)?
) -> some View {
    if let onPlay { Button { onPlay() } label: { Label("Play", systemImage: "play.fill") } }
    if let onPlayNext { Button { onPlayNext() } label: { Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward") } }
    if let onQueue { Button { onQueue() } label: { Label("Add to Queue", systemImage: "text.badge.plus") } }
    if let onCast { Button { onCast() } label: { Label("Cast to TV", systemImage: "tv.badge.wifi") } }
    if let onToggleSave {
        Button { onToggleSave() } label: {
            Label(isSaved ? "Remove from Saved" : "Save for Later",
                  systemImage: isSaved ? "bookmark.fill" : "bookmark")
        }
    }
    if let onToggleDownload {
        Button { onToggleDownload() } label: {
            Label(isDownloaded ? "Remove Download" : "Download",
                  systemImage: isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
        }
    }
    if let url = RowActions.youtubeURL(videoId: videoId) {
        ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
    }
}
