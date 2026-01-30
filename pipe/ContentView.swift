import SwiftUI
import AVKit
import AVFoundation
import MediaPlayer
import Combine

class PlayerState: ObservableObject {
    @Published var error: String?
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var currentTitle: String?
    @Published var currentArtist: String?
    @Published var currentThumbnail: String?
    @Published var playbackSpeed: Float = 1.0
    
    private var player: AVPlayer?
    private var currentVideoId: String?
    private var positions: [String: Double] = [:]
    private var timeObserver: Any?
    
    init() {
        setupAudioSession()
        setupRemoteCommands()
    }
    
    func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        try? AVAudioSession.sharedInstance().setActive(true)
    }
    
    func setupRemoteCommands() {
        let cmd = MPRemoteCommandCenter.shared()
        cmd.playCommand.addTarget { [weak self] _ in self?.resume(); return .success }
        cmd.pauseCommand.addTarget { [weak self] _ in self?.pause(); return .success }
        cmd.togglePlayPauseCommand.addTarget { [weak self] _ in self?.togglePlayPause(); return .success }
        cmd.skipForwardCommand.preferredIntervals = [10]
        cmd.skipForwardCommand.addTarget { [weak self] _ in self?.skip(10); return .success }
        cmd.skipBackwardCommand.preferredIntervals = [10]
        cmd.skipBackwardCommand.addTarget { [weak self] _ in self?.skip(-10); return .success }
    }
    
    func togglePlayPause() { if isPlaying { pause() } else { resume() } }
    func resume() { player?.play(); isPlaying = true; updateNowPlaying() }
    func pause() { player?.pause(); isPlaying = false; updateNowPlaying() }
    
    func skip(_ seconds: Double) {
        let newTime = max(0, min(currentTime + seconds, duration))
        seek(to: newTime)
    }
    
    func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 1))
        currentTime = time
        updateNowPlaying()
    }
    
    func setSpeed(_ speed: Float) {
        playbackSpeed = speed
        if isPlaying { player?.rate = speed }
        updateNowPlaying()
    }
    
    func updateNowPlaying() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTitle ?? "",
            MPMediaItemPropertyArtist: currentArtist ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? playbackSpeed : 0
        ]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    func play(videoId: String, urlString: String, title: String?, artist: String?, thumbnail: String?) {
        error = nil
        setupAudioSession()
        
        guard let url = URL(string: urlString) else { error = "Invalid URL"; return }
        
        savePosition()
        currentVideoId = videoId
        currentTitle = title
        currentArtist = artist
        currentThumbnail = thumbnail
        currentTime = 0
        duration = 0
        
        if let old = timeObserver, let p = player { p.removeTimeObserver(old); timeObserver = nil }
        
        player = AVPlayer(url: url)
        
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 1, preferredTimescale: 1), queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds
            if let d = self.player?.currentItem?.duration.seconds, d.isFinite, d > 0 { self.duration = d }
        }
        
        if let pos = positions[videoId] { player?.seek(to: CMTime(seconds: pos, preferredTimescale: 1)) }
        player?.play()
        isPlaying = true
        updateNowPlaying()
    }
    
    func savePosition() {
        guard let id = currentVideoId else { return }
        positions[id] = currentTime
    }
}

struct ContentView: View {
    @StateObject private var player = PlayerState()
    
    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                SearchView(player: player)
            }
            
            if player.currentTitle != nil {
                MiniPlayerBar(player: player)
            }
        }
    }
}

struct MiniPlayerBar: View {
    @ObservedObject var player: PlayerState
    @State private var showFull = false
    
    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: player.currentTime, total: max(player.duration, 1)).tint(.accentColor)
            
            HStack {
                AsyncImage(url: URL(string: player.currentThumbnail ?? "")) { $0.resizable() } placeholder: { Color.gray }
                    .frame(width: 44, height: 44).cornerRadius(4)
                
                VStack(alignment: .leading) {
                    Text(player.currentTitle ?? "").font(.footnote).lineLimit(1)
                    Text(player.currentArtist ?? "").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill").font(.title3)
                }
            }.padding(10)
        }
        .background(.thinMaterial)
        .onTapGesture { showFull = true }
        .sheet(isPresented: $showFull) { FullPlayerSheet(player: player) }
    }
}

struct FullPlayerSheet: View {
    @ObservedObject var player: PlayerState
    
    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(.secondary).frame(width: 40, height: 5).padding(.top)
            
            Spacer()
            
            AsyncImage(url: URL(string: player.currentThumbnail ?? "")) { $0.resizable().scaledToFit() } placeholder: { Color.gray }
                .frame(maxWidth: 260, maxHeight: 260).cornerRadius(8)
            
            Text(player.currentTitle ?? "").font(.title3).bold().lineLimit(2).multilineTextAlignment(.center).padding(.horizontal)
            Text(player.currentArtist ?? "").foregroundStyle(.secondary)
            
            VStack {
                ProgressView(value: player.currentTime, total: max(player.duration, 1)).tint(.accentColor)
                HStack {
                    Text(fmt(player.currentTime)).font(.caption)
                    Spacer()
                    Text(fmt(player.duration)).font(.caption)
                }.foregroundStyle(.secondary)
            }.padding(.horizontal, 30)
            
            HStack(spacing: 50) {
                Button { player.skip(-10) } label: { Image(systemName: "gobackward.10").font(.title2) }
                Button { player.togglePlayPause() } label: {
                    Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.system(size: 60))
                }
                Button { player.skip(10) } label: { Image(systemName: "goforward.10").font(.title2) }
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
            
            Spacer()
        }
    }
    
    func fmt(_ s: Double) -> String {
        guard s.isFinite, s >= 0 else { return "0:00" }
        let m = Int(s) / 60, sec = Int(s) % 60
        return String(format: "%d:%02d", m, sec)
    }
}

struct SearchView: View {
    @ObservedObject var player: PlayerState
    @State private var query = ""
    @State private var results: [SearchItem] = []
    @State private var loading = false
    
    var body: some View {
        List(results) { item in
            if item.isChannel {
                NavigationLink(value: item) { ChannelRow(item: item) }
            } else {
                NavigationLink(value: item) { AudioRow(item: item) }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Pipe")
        .navigationDestination(for: SearchItem.self) { item in
            if item.isChannel { ChannelView(channelId: item.channelId, player: player) }
            else { DetailView(videoId: item.videoId, player: player) }
        }
        .searchable(text: $query, prompt: "Search")
        .onSubmit(of: .search) {
            loading = true
            Task { results = (try? await PipedAPI.search(query)) ?? []; loading = false }
        }
        .overlay { if loading { ProgressView() } }
    }
}

struct ChannelRow: View {
    let item: SearchItem
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: item.displayThumbnail)) { $0.resizable() } placeholder: { Color.gray }
                .frame(width: 44, height: 44).clipShape(Circle())
            Text(item.displayTitle).font(.headline)
        }
    }
}

struct AudioRow: View {
    let item: SearchItem
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: item.displayThumbnail)) { $0.resizable() } placeholder: { Color.gray }
                .frame(width: 50, height: 50).cornerRadius(6)
            VStack(alignment: .leading) {
                Text(item.displayTitle).font(.subheadline).lineLimit(2)
                Text(item.displayUploader).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct ChannelView: View {
    let channelId: String
    @ObservedObject var player: PlayerState
    @State private var channel: ChannelResponse?
    
    var body: some View {
        Group {
            if let ch = channel {
                List(ch.relatedStreams) { v in
                    NavigationLink(value: v) {
                        HStack {
                            AsyncImage(url: URL(string: v.thumbnail)) { $0.resizable() } placeholder: { Color.gray }
                                .frame(width: 50, height: 50).cornerRadius(6)
                            Text(v.title).font(.subheadline).lineLimit(2)
                        }
                    }
                }
                .navigationDestination(for: RelatedStream.self) { DetailView(videoId: $0.videoId, player: player) }
                .navigationTitle(ch.name)
            } else { ProgressView() }
        }
        .task { channel = try? await PipedAPI.channel(channelId) }
    }
}

struct DetailView: View {
    let videoId: String
    @ObservedObject var player: PlayerState
    @State private var stream: StreamResponse?
    @State private var loading = false
    
    var body: some View {
        ScrollView {
            if let s = stream {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        AsyncImage(url: URL(string: s.thumbnailUrl)) { $0.resizable() } placeholder: { Color.gray }
                            .frame(width: 100, height: 100).cornerRadius(8)
                        VStack(alignment: .leading) {
                            Text(s.title).font(.headline)
                            Text(s.uploader).foregroundStyle(.secondary)
                            Button { play(s) } label: {
                                Label("Play", systemImage: "play.fill")
                                    .padding(.horizontal, 16).padding(.vertical, 8)
                                    .background(Color.accentColor).foregroundColor(.white).cornerRadius(20)
                            }.padding(.top, 4)
                        }
                    }
                    if let d = s.description { Text(d).font(.body) }
                }.padding()
            } else { ProgressView().padding() }
        }
        .navigationTitle("Episode")
        .task { stream = try? await PipedAPI.streams(videoId) }
    }
    
    func play(_ s: StreamResponse) {
        var url = s.videoStreams.first { $0.mimeType.contains("mp4") && $0.videoOnly == false }?.url ?? ""
        if let r = url.range(of: "host=([^&]+)", options: .regularExpression), let h = url[r].split(separator: "=").last {
            url = url.replacingOccurrences(of: "https://pipedproxy.jpc.io/", with: "https://\(h)/")
            url = url.replacingOccurrences(of: "host=\(h)&", with: "").replacingOccurrences(of: "&host=\(h)", with: "")
        }
        player.play(videoId: videoId, urlString: url, title: s.title, artist: s.uploader, thumbnail: s.thumbnailUrl)
    }
}

func formatDuration(_ seconds: Int) -> String {
    let m = seconds / 60, s = seconds % 60
    return String(format: "%d:%02d", m, s)
}
