import SwiftUI

struct FollowingView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var following: FollowingStore
    @ObservedObject var recents: RecentsStore
    
    var body: some View {
        List {
            ForEach(following.channels) { channel in
                NavigationLink(value: channel) {
                    HStack {
                        AsyncImage(url: URL(string: channel.thumbnail)) { $0.resizable() } placeholder: { Color.gray }
                            .frame(width: 50, height: 50).clipShape(Circle())
                        Text(channel.name).font(.headline)
                    }
                }
            }
            .onDelete { indexSet in
                indexSet.forEach { following.channels.remove(at: $0) }
                following.save()
            }
        }
        .listStyle(.plain)
        .navigationTitle("Following")
        .navigationDestination(for: FollowedChannel.self) { channel in
            ChannelView(channelId: channel.id, player: player, following: following, recents: recents)
        }
        .overlay {
            if following.channels.isEmpty {
                ContentUnavailableView("No Channels", systemImage: "heart", description: Text("Follow channels to see them here"))
            }
        }
    }
}
