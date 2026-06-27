import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @ObservedObject var player: PlayerState
    
    var body: some View {
        if let avPlayer = player.player {
            PiPVideoPlayer(player: avPlayer)
                .ignoresSafeArea()
        }
    }
}
