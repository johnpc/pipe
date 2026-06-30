import SwiftUI

/// The Full Player's "Info" tab: the now-playing video's chapters (tap to seek)
/// and description (with tappable timestamp links that seek the live player).
struct PlayerInfoTab: View {
    let stream: StreamResponse
    @ObservedObject var player: PlayerState

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Chapters live in their own player tab now; Info shows the description.
            if let description = stream.description, !description.isEmpty {
                Text("About").font(.headline)
                Text(HTMLText.attributed(description)).font(.body).tint(.accentColor)
            } else {
                ContentUnavailableView("No Details", systemImage: "doc.plaintext")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            guard let secs = DescriptionLinks.seekSeconds(from: url) else { return .systemAction }
            seek(to: secs)
            return .handled
        })
    }

    private func seek(to seconds: Double) {
        // Only the playing item's timeline is meaningful here; just seek.
        player.seek(to: seconds)
        if !player.isPlaying { player.resume() }
    }
}
