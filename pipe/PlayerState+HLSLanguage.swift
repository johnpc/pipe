import AVFoundation

/// Audio language for HLS video mode: the master carries one audible option
/// per language, so the choice is a media selection on the playing item
/// rather than a different URL. Applied once the item is ready to play.
extension PlayerState {
    func applyHLSAudioSelection() {
        guard videoMode, currentIndex >= 0, currentIndex < queue.count,
              !queue[currentIndex].hlsUrl.isEmpty, let playerItem = player?.currentItem else { return }
        let preferred = queue[currentIndex].audioLanguage ?? pipedAudioLanguage
        let videoId = queue[currentIndex].videoId
        Task { [weak self] in
            guard let group = try? await playerItem.asset.loadMediaSelectionGroup(for: .audible) else { return }
            let tags = group.options.map(\.extendedLanguageTag)
            guard let index = HLSPlaybackLogic.audioSelection(tags: tags, preferred: preferred) else { return }
            let option = group.options[index]
            await MainActor.run {
                guard let self, self.player?.currentItem === playerItem else { return }
                playerItem.select(option, in: group)
                self.log.event("play", "hls audio selection", fields: ["videoId": videoId, "tag": option.extendedLanguageTag ?? "-"])
            }
        }
    }
}
