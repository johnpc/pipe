import SwiftUI

struct MiniPlayerBar: View {
    @ObservedObject var player: PlayerState
    @State private var showFull = false
    @Environment(\.horizontalSizeClass) private var sizeClass
    
    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: player.currentTime, total: max(player.duration, 1))
                .tint(.accentColor)
                .scaleEffect(x: 1, y: 0.5, anchor: .center)
            
            HStack {
                AsyncImage(url: URL(string: player.currentThumbnail ?? "")) { $0.resizable() } placeholder: { Color.gray }
                    .frame(width: 40, height: 40).cornerRadius(4)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(player.currentTitle ?? "").font(.footnote).lineLimit(1)
                        .accessibilityIdentifier("miniPlayerTitle")
                    // The second line says what the player is doing while that
                    // matters (loading, buffering, failed); otherwise the artist.
                    Text(player.phase.subtitle(artist: player.currentArtist))
                        .font(.caption2).lineLimit(1)
                        .foregroundStyle(player.phase.isFailed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .accessibilityIdentifier("miniPlayerStatus")
                }
                if sizeClass == .regular {
                    // A wide bar earns transport: time beside the title, skip
                    // back / forward around the play control at the trailing edge.
                    Text("\(formatTime(player.currentTime)) / \(formatTime(player.duration))")
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        .padding(.leading, 24)
                }
                Spacer()
                if sizeClass == .regular {
                    Button { player.skip(-10) } label: {
                        Image(systemName: "gobackward.10").font(.title3).frame(width: 44, height: 44)
                    }
                    .accessibilityIdentifier("miniSkipBackButton")
                }
                // While buffering, dim the control under a spinner but keep it
                // tappable so the user can still pause a long buffer.
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .opacity(player.isBuffering ? 0.35 : 1)
                        .overlay { if player.isBuffering { ProgressView().accessibilityIdentifier("bufferingIndicator") } }
                }
                .accessibilityIdentifier("miniPlayPauseButton")
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
                .accessibilityValue(player.phase.label)
                if sizeClass == .regular {
                    Button { player.skip(10) } label: {
                        Image(systemName: "goforward.10").font(.title3).frame(width: 44, height: 44)
                    }
                    .accessibilityIdentifier("miniSkipForwardButton")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
            Divider()
        }
        .contentShape(Rectangle())
        .onTapGesture { showFull = true }
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in handleSwipe(value.translation) }
        )
        .sheet(isPresented: $showFull) { FullPlayerSheet(player: player) }
    }

    private func handleSwipe(_ t: CGSize) {
        let action = SwipeAction.from(translationWidth: t.width, translationHeight: t.height)
        if action.apply(to: player) { Haptics.tap() }
    }
}
