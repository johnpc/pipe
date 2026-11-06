import SwiftUI

/// The Full Player's row of playback-mode pills: Video/Audio toggle, the
/// audio-language menu on dubbed videos, and the Cast button.
struct PlayerModeControls: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var detail: NowPlayingDetail

    var body: some View {
        HStack(spacing: 16) {
            // Video/Audio toggle — reloads the stream at the same position
            Button {
                player.toggleVideoMode()
            } label: {
                Label(player.videoMode ? "Audio Only" : "Show Video", systemImage: player.videoMode ? "waveform" : "video")
                    .modePill()
            }
            AudioLanguageMenu(player: player, detail: detail)
            if let cast = player.cast {
                CastButton(cast: cast)
            }
        }
    }
}

extension View {
    /// Shared capsule styling for the mode pills.
    func modePill() -> some View {
        font(.subheadline)
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Color.secondary.opacity(0.2))
            .cornerRadius(20)
    }
}
