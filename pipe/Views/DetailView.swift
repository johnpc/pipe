import SwiftUI

struct DetailView: View {
    let videoId: String
    @ObservedObject var player: PlayerState
    @State private var stream: StreamResponse?
    
    var body: some View {
        ScrollView {
            if let s = stream {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        AsyncImage(url: URL(string: s.thumbnailUrl)) { $0.resizable() } placeholder: { Color.gray }
                            .frame(width: 100, height: 100).cornerRadius(8)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(s.title).font(.headline)
                            Text(s.uploader).foregroundStyle(.secondary)
                            
                            HStack(spacing: 12) {
                                Button { playNow(s) } label: {
                                    Label("Play", systemImage: "play.fill")
                                        .font(.subheadline)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Color.accentColor).foregroundColor(.white).cornerRadius(16)
                                }
                                Button { addToQueue(s) } label: {
                                    Label("Queue", systemImage: "plus")
                                        .font(.subheadline)
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(Color.secondary.opacity(0.2)).cornerRadius(16)
                                }
                            }
                        }
                    }
                    if let d = s.description { Text(d).font(.body) }
                }.padding()
            } else { ProgressView().padding() }
        }
        .navigationTitle("Episode")
        .task { stream = try? await PipedAPI.streams(videoId) }
    }
    
    private func playNow(_ s: StreamResponse) {
        player.play(videoId: videoId, urlString: getStreamUrl(s), title: s.title, artist: s.uploader, thumbnail: s.thumbnailUrl, duration: s.duration)
    }
    
    private func addToQueue(_ s: StreamResponse) {
        player.addToQueue(videoId: videoId, url: getStreamUrl(s), title: s.title, artist: s.uploader, thumbnail: s.thumbnailUrl, duration: s.duration)
    }
}
