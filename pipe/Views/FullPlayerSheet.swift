import SwiftUI
import AVKit

struct FullPlayerSheet: View {
    @ObservedObject var player: PlayerState
    @StateObject private var detail = NowPlayingDetail()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Capsule().fill(.secondary).frame(width: 40, height: 5).padding(.top)
                
                if PiPLogic.isEligible(videoMode: player.videoMode, hasPlayer: player.player != nil), let avPlayer = player.player {
                    PiPVideoPlayer(player: avPlayer)
                        .frame(height: 200)
                        .cornerRadius(8)
                        .padding(.horizontal)
                } else {
                    AsyncImage(url: URL(string: player.currentThumbnail ?? "")) { $0.resizable().scaledToFit() } placeholder: { Color.gray }
                        .frame(maxWidth: 260, maxHeight: 260).cornerRadius(8)
                }
                
                Text(player.currentTitle ?? "").font(.title3).bold().lineLimit(2).multilineTextAlignment(.center).padding(.horizontal)
                Text(player.currentArtist ?? "").foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    // Video/Audio toggle — reloads the stream at the same position
                    Button {
                        player.toggleVideoMode()
                    } label: {
                        Label(player.videoMode ? "Audio Only" : "Show Video", systemImage: player.videoMode ? "waveform" : "video")
                            .font(.subheadline)
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(20)
                    }
                    if let cast = player.cast {
                        CastButton(cast: cast)
                    }
                }

                SponsorBlockToggle(player: player)
                
                VStack {
                    Slider(value: Binding(
                        get: { player.currentTime },
                        set: { player.seek(to: $0) }
                    ), in: 0...max(player.duration, 1))
                    .tint(.accentColor)
                    HStack {
                        Text(formatTime(player.currentTime)).font(.caption)
                        Spacer()
                        Text(formatTime(player.duration)).font(.caption)
                    }.foregroundStyle(.secondary)
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
                
                PlayerTabsView(player: player, detail: detail)
            }
            .padding(.bottom, 30)
        }
        .toastOverlay()
    }
}
