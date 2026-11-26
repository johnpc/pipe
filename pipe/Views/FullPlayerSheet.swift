import SwiftUI
import AVKit

struct FullPlayerSheet: View {
    @ObservedObject var player: PlayerState
    @StateObject private var detail = NowPlayingDetail()

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if sizeClass == .regular {
            // A fixed card: the content sets the size, so no dead space either side.
            wideLayout
                .frame(width: 900, height: 720)
                .toastOverlay()
                .presentationSizing(.fitted)
                .presentationDragIndicator(.hidden)
        } else {
            compactLayout.toastOverlay()
        }
    }

    /// Phone: one scrolling column, tabs under the controls.
    private var compactLayout: some View {
        ScrollView {
            VStack(spacing: 20) {
                grabber
                header
                controls
                PlayerTabsView(player: player, detail: detail)
            }
            .padding(.bottom, 30)
        }
    }

    /// iPad: artwork and transport on the left, queue / chapters / comments on
    /// the right, so the sheet's extra width is used instead of letterboxed.
    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 0) {
            ScrollView {
                VStack(spacing: 18) { header; controls }
                    .padding(.top, 28).padding(.bottom, 24)
            }
            .frame(width: 460)
            Divider()
            ZStack(alignment: .topTrailing) {
                ScrollView {
                    PlayerTabsView(player: player, detail: detail, wide: true).padding(.top, 20)
                }
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
                }
                .padding(12)
                .accessibilityIdentifier("closePlayerButton")
                .accessibilityLabel("Close")
            }
        }
    }

    private var grabber: some View {
        Capsule().fill(.secondary).frame(width: 40, height: 5).padding(.top)
    }

    @ViewBuilder
    private var header: some View {
        if PiPLogic.isEligible(videoMode: player.videoMode, hasPlayer: player.player != nil), let avPlayer = player.player {
            PiPVideoPlayer(player: avPlayer, log: player.log)
                .frame(height: 200)
                .cornerRadius(8)
                .padding(.horizontal)
        } else {
            AsyncImage(url: URL(string: player.currentThumbnail ?? "")) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                .aspectRatio(16 / 9, contentMode: .fit)
                .frame(maxWidth: sizeClass == .regular ? 380 : 260)
                .clipped().cornerRadius(10)
                .padding(.horizontal, sizeClass == .regular ? 24 : 0)
        }

        Text(player.currentTitle ?? "").font(.title3).bold().lineLimit(2).multilineTextAlignment(.center).padding(.horizontal)
        Text(player.currentArtist ?? "").foregroundStyle(.secondary)
        if let status = player.phase.statusText {
            Text(status).font(.caption)
                .foregroundStyle(player.phase.isFailed ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                .accessibilityIdentifier("playerStatus")
        }
    }

    @ViewBuilder
    private var controls: some View {
        PlayerModeControls(player: player, detail: detail)

        SponsorBlockToggle(player: player)
        
        VStack {
            PlayerScrubber(clock: player.clock) { player.seek(to: $0) }
            if let chapter = player.currentChapterTitle {
                Label(chapter, systemImage: "list.bullet")
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 2)
                    .accessibilityIdentifier("currentChapterLabel")
            }
        }.padding(.horizontal, 30)
        
        HStack(spacing: 36) {
            Button { player.playPrevious() } label: { Image(systemName: "backward.fill").font(.title2) }
                .disabled(player.currentIndex <= 0)
            Button { player.skip(-10) } label: { Image(systemName: "gobackward.10").font(.title2) }
            Button { player.togglePlayPause() } label: {
                Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .opacity(player.isBuffering ? 0.35 : 1)
                    .overlay { if player.isBuffering { ProgressView() } }
            }
            .accessibilityIdentifier("playPauseButton")
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            .accessibilityValue(player.phase.label)
            Button { player.skip(10) } label: { Image(systemName: "goforward.10").font(.title2) }
            Button { player.playNext() } label: { Image(systemName: "forward.fill").font(.title2) }
                .disabled(player.currentIndex >= player.queue.count - 1)
        }
        
        HStack {
            ForEach([0.5, 1.0, 1.5, 2.0], id: \.self) { s in
                Button { player.setSpeed(Float(s)) } label: {
                    Text(s == 1 ? "1x" : "\(s, specifier: "%.1f")x")
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(player.playbackSpeed == Float(s) ? Color.accentColor : Color.secondary.opacity(0.2))
                        .foregroundColor(player.playbackSpeed == Float(s) ? .white : .primary)
                        .cornerRadius(12)
                }
            }
        }.font(.footnote)
    }
}
