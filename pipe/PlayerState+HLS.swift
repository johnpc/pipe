import AVFoundation

/// Native HLS playback of YouTube's own master playlist. Video mode hands the
/// master to AVPlayer (which picks the variant and, via media selection, the
/// audio language — see +HLSLanguage). Audio mode plays just the chosen
/// language's audio rendition playlist, so no video is downloaded. Direct
/// googlevideo URLs stay as the fallback for instances that offer no `hls`.
extension PlayerState {
    func startHLS(_ item: QueueItem, generation: Int) {
        guard let master = URL(string: item.hlsUrl) else {
            log.event("play", "bad hls url", fields: ["videoId": item.videoId, "result": "failed"])
            apply(.unplayable(title: item.title))
            return
        }
        if videoMode {
            log.event("play", "hls video", fields: ["videoId": item.videoId])
            startPlayer(AVPlayer(url: master), for: item)
            return
        }
        let language = item.audioLanguage ?? pipedAudioLanguage
        // The lifecycle is in .loading (spinner + pause glyph) while the master is read.
        log.event("play", "hls audio", fields: ["videoId": item.videoId, "language": language])
        Task { [weak self] in
            let rendition = await HLSMasterLoader.audioPlaylist(master: master, preferred: language)
            await MainActor.run {
                // A newer load owns the player now (see +Composed for the same guard).
                guard let self, self.lifecycle.isCurrent(generation) else { return }
                if rendition == nil {
                    self.log.event("play", "hls audio rendition missing, using master", fields: ["videoId": item.videoId])
                }
                self.startPlayer(AVPlayer(url: rendition ?? master), for: item)
            }
        }
    }
}
