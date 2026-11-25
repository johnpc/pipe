import SwiftUI

/// Tabbed section under the Full Player controls: Queue, Up Next (related),
/// Info (description + chapters), and Comments — all for the now-playing video.
/// Reachable while playback continues, so playing a video is never a dead end.
struct PlayerTabsView: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var detail: NowPlayingDetail
    /// Regular width: a segmented picker instead of the scrolling chip strip,
    /// which clipped its last tab inside the player sheet's right column.
    var wide: Bool = false
    @State private var tab: PlayerTab = .queue
    /// Wide layouts inset list-style sections to line up with the picker.
    private var sideInset: CGFloat { wide ? 8 : 0 }

    enum PlayerTab: String, CaseIterable {
        case queue = "Queue", upNext = "Up Next", chapters = "Chapters", info = "Info", comments = "Comments", transcript = "Transcript"

        /// Glyph for the segmented picker on wide layouts, where six words don't fit.
        var icon: String {
            switch self {
            case .queue: return "list.number"
            case .upNext: return "forward.end"
            case .chapters: return "list.bullet"
            case .info: return "info.circle"
            case .comments: return "text.bubble"
            case .transcript: return "text.quote"
            }
        }
    }

    /// Chapters tab only appears when the now-playing video actually has them.
    private var visibleTabs: [PlayerTab] {
        PlayerTab.allCases.filter { $0 != .chapters || ChaptersLogic.hasChapters(detail.state.value?.chapters) }
    }

    var body: some View {
        VStack(spacing: 12) {
            if wide {
                // Each section names itself in its own header, so no caption here.
                Picker("Section", selection: $tab) {
                    ForEach(visibleTabs, id: \.self) { t in
                        Image(systemName: t.icon).tag(t).accessibilityLabel(t.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("playerTabPicker")
                .padding(.horizontal).padding(.trailing, 40)  // room for the close button
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(visibleTabs, id: \.self) { t in
                            TabPill(title: t == .comments ? "💬" : t.rawValue, isSelected: tab == t) { tab = t }
                                .accessibilityIdentifier("playerTab-\(t.rawValue)")
                        }
                    }.padding(.horizontal)
                }
            }
            content
        }
        .task(id: player.currentVideoId) { await detail.load(videoId: player.currentVideoId) }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .queue:
            QueueSection(player: player).padding(.horizontal, sideInset)
        case .upNext:
            relatedContent.padding(.horizontal, sideInset)
        case .chapters:
            chaptersContent.padding(.horizontal)
        case .info:
            infoContent.padding(.horizontal)
        case .transcript:
            TranscriptTab(player: player, detail: detail).padding(.horizontal)
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
    private var chaptersContent: some View {
        if let chapters = detail.state.value?.chapters, ChaptersLogic.hasChapters(chapters) {
            VStack(alignment: .leading) {
                // Same video is playing; seek in place rather than reloading.
                ChaptersView(chapters: chapters, current: player.currentChapterTitle) { player.seek(to: Double($0.start)) }
                Spacer()
            }
        } else if detail.state.isLoading {
            ProgressView().padding()
        } else {
            emptyTab("No Chapters", "list.bullet")
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
