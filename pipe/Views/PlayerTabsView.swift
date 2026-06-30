import SwiftUI

/// Tabbed section under the Full Player controls: Queue, Up Next (related),
/// Info (description + chapters), and Comments — all for the now-playing video.
/// Reachable while playback continues, so playing a video is never a dead end.
struct PlayerTabsView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var detail: NowPlayingDetail
    @State private var tab: PlayerTab = .queue

    enum PlayerTab: String, CaseIterable { case queue = "Queue", upNext = "Up Next", info = "Info", comments = "Comments" }

    var body: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PlayerTab.allCases, id: \.self) { t in
                        TabPill(title: t == .comments ? "💬" : t.rawValue, isSelected: tab == t) { tab = t }
                            .accessibilityIdentifier("playerTab-\(t.rawValue)")
                    }
                }.padding(.horizontal)
            }
            content
        }
        .task(id: player.currentVideoId) { await detail.load(videoId: player.currentVideoId) }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .queue:
            QueueSection(player: player)
        case .upNext:
            relatedContent
        case .info:
            infoContent.padding(.horizontal)
        case .comments:
            if let id = player.currentVideoId {
                CommentsList(videoId: id) { player.seek(to: $0) }.frame(minHeight: 300)
            } else { emptyTab("No Comments", "text.bubble") }
        }
    }

    @ViewBuilder
    private var relatedContent: some View {
        if let related = detail.state.value?.relatedStreams, !related.isEmpty {
            RelatedVideosView(related: related, player: player).padding(.horizontal)
        } else if detail.state.isLoading {
            ProgressView().padding()
        } else {
            emptyTab("Nothing Up Next", "rectangle.stack")
        }
    }

    @ViewBuilder
    private var infoContent: some View {
        if let stream = detail.state.value {
            PlayerInfoTab(stream: stream, player: player)
        } else if detail.state.isLoading {
            ProgressView().padding()
        } else {
            emptyTab("No Details", "doc.plaintext")
        }
    }

    private func emptyTab(_ title: String, _ icon: String) -> some View {
        ContentUnavailableView(title, systemImage: icon).frame(minHeight: 200)
    }
}
