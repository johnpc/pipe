import SwiftUI

/// Picks the now-playing video's audio language. Shown only in audio mode on
/// videos that offer more than one language (dubbed videos).
struct AudioLanguageMenu: View {
    @ObservedObject var player: PlayerState
    @ObservedObject var detail: NowPlayingDetail

    private var streams: [AudioStream] { detail.state.value?.audioStreams ?? [] }
    private var languages: [String] { AudioLanguageLogic.languages(in: streams) }
    private var current: String? {
        AudioLanguageLogic.activeLanguage(playingURL: player.currentAudioURL,
                                          chosen: player.currentAudioLanguageChoice, in: streams)
    }

    var body: some View {
        if !player.videoMode && languages.count > 1 {
            Menu {
                ForEach(languages, id: \.self) { code in
                    Button {
                        player.selectAudioLanguage(code, from: streams)
                    } label: {
                        if code == current {
                            Label(AudioLanguageLogic.displayName(code), systemImage: "checkmark")
                        } else {
                            Text(AudioLanguageLogic.displayName(code))
                        }
                    }
                }
            } label: {
                Label(current.map { AudioLanguageLogic.displayName($0) } ?? "Language", systemImage: "globe")
                    .modePill()
            }
            .accessibilityIdentifier("audioLanguageMenu")
        }
    }
}
