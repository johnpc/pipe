import MediaPlayer
import UIKit

/// Now-playing info for the lock screen / Control Center, including async-loaded
/// cover artwork (cached by URL so we don't refetch on every progress tick).
extension PlayerState {
    func updateNowPlaying() {
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = currentTitle ?? ""
        info[MPMediaItemPropertyArtist] = currentArtist ?? ""
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0
        if let art = Self.artworkCache[currentThumbnail ?? ""] {
            info[MPMediaItemPropertyArtwork] = art
        } else {
            info[MPMediaItemPropertyArtwork] = nil
            loadArtwork(from: currentThumbnail)
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    /// Fetch the thumbnail once, cache the artwork, then refresh now-playing.
    private func loadArtwork(from urlString: String?) {
        guard let urlString, let url = URL(string: urlString) else { return }
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            await MainActor.run {
                Self.artworkCache[urlString] = artwork
                // Only apply if this is still the current item.
                if self?.currentThumbnail == urlString { self?.updateNowPlaying() }
            }
        }
    }

    /// Small URL→artwork cache shared across player instances.
    nonisolated(unsafe) static var artworkCache: [String: MPMediaItemArtwork] = [:]
}
