import AVFoundation

/// Video mode plays the video-only track and the chosen audio track together
/// as one HLS program (see `StreamComposition`), so a dubbed video honors the
/// audio language with the picture showing — the muxed stream carries a single
/// fixed track. Reading the two indexes is async; if either fails, the muxed
/// `fallback` plays, so an instance without video-only tracks (or a dead track
/// URL) behaves as before.
extension PlayerState {
    func startComposed(_ item: QueueItem, pair: ComposedPlaybackLogic.Pair, fallback: URL) {
        let generation = playGeneration
        // Show intent (playing + spinner) while the tracks load; the observers
        // that would otherwise maintain these aren't installed yet.
        isPlaying = true
        isBuffering = true
        log.event("play", "composing", fields: ["videoId": item.videoId])
        Task { [weak self] in
            let built = await Self.compose(pair)
            await MainActor.run {
                // A newer load (next item, mode toggle, language switch) owns
                // the player now; installing this one would overlap audio.
                guard let self, self.playGeneration == generation else { return }
                self.finishComposed(item, built: built, fallback: fallback)
            }
        }
    }

    private static func compose(_ pair: ComposedPlaybackLogic.Pair) async -> Result<ComposedStream, Error> {
        do {
            return .success(try await StreamComposition.build(video: pair.video, audio: pair.audio))
        } catch {
            return .failure(error)
        }
    }

    private func finishComposed(_ item: QueueItem, built: Result<ComposedStream, Error>, fallback: URL) {
        switch built {
        case .success(let stream):
            composedLoader = stream.loader
            startPlayer(AVPlayer(playerItem: stream.item), for: item)
        case .failure(let error):
            log.event("play", "compose failed, using muxed", fields: ["videoId": item.videoId, "error": error.diagnosticDescription])
            startPlayer(AVPlayer(url: fallback), for: item)
        }
    }
}
