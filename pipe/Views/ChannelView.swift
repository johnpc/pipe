import SwiftUI

struct ChannelView: View {
    let channelId: String
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @State private var channel: ChannelResponse?
    
    var body: some View {
        Group {
            if let ch = channel {
                List(ch.relatedStreams) { v in
                    NavigationLink(value: v) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 12) {
                                ZStack(alignment: .bottomTrailing) {
                                    AsyncImage(url: URL(string: v.thumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                                        .frame(width: 100, height: 56).clipped().cornerRadius(6)
                                    if v.duration > 0 {
                                        Text(formatDuration(v.duration))
                                            .font(.caption2).bold()
                                            .padding(.horizontal, 4).padding(.vertical, 2)
                                            .background(.black.opacity(0.7))
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                            .padding(4)
                                    }
                                }
                                
                                if let uploader = v.uploaderName {
                                    Text(uploader).font(.caption).foregroundStyle(.secondary).lineLimit(2).truncationMode(.tail)
                                }
                                
                                Spacer()
                                
                                Button { playVideo(v) } label: {
                                    Image(systemName: "play.circle.fill").font(.title2)
                                }.buttonStyle(.plain)
                                Button { queueVideo(v) } label: {
                                    Image(systemName: "text.badge.plus").font(.title3)
                                }.buttonStyle(.plain)
                            }
                            
                            Text(v.title).font(.subheadline).lineLimit(3)
                        }
                        .padding(.vertical, 8)
                    }
                }
                .navigationDestination(for: RelatedStream.self) { DetailView(videoId: $0.videoId, player: player) }
                .navigationTitle(ch.name)
                .toolbar {
                    Button {
                        if following.isFollowing(channelId) {
                            following.unfollow(channelId)
                        } else {
                            following.follow(FollowedChannel(id: channelId, name: ch.name, thumbnail: ch.avatarUrl ?? ""))
                        }
                    } label: {
                        Image(systemName: following.isFollowing(channelId) ? "heart.fill" : "heart")
                            .foregroundColor(following.isFollowing(channelId) ? .red : .primary)
                    }
                }
            } else { ProgressView() }
        }
        .task { channel = try? await PipedAPI.channel(channelId) }
    }
    
    private func playVideo(_ v: RelatedStream) {
        Task {
            guard let stream = try? await PipedAPI.streams(v.videoId) else { return }
            let url = getStreamUrl(stream)
            await MainActor.run {
                player.play(videoId: v.videoId, urlString: url, title: stream.title, artist: stream.uploader, thumbnail: stream.thumbnailUrl, duration: stream.duration)
            }
        }
    }
    
    private func queueVideo(_ v: RelatedStream) {
        Task {
            guard let stream = try? await PipedAPI.streams(v.videoId) else { return }
            let url = getStreamUrl(stream)
            await MainActor.run {
                player.addToQueue(videoId: v.videoId, url: url, title: stream.title, artist: stream.uploader, thumbnail: stream.thumbnailUrl, duration: stream.duration)
            }
        }
    }
}
