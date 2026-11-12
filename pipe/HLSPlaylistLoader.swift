import AVFoundation

/// Serves the generated playlists to AVFoundation. The asset's URL uses the
/// `pipe-hls` scheme, so every playlist request comes here; segment requests
/// (plain https byte ranges) never do. Keep the loader alive as long as the
/// item plays — the resource loader only holds its delegate weakly.
final class HLSPlaylistLoader: NSObject, AVAssetResourceLoaderDelegate {
    private let playlists: [String: Data]
    let queue = DispatchQueue(label: "pipe.hls-playlists")

    init(playlists: [String: String]) {
        self.playlists = playlists.mapValues { Data($0.utf8) }
    }

    /// The playlist body for a request URL, or nil when it's not one of ours.
    func playlist(for url: URL?) -> Data? {
        HLSPlaylist.name(for: url).flatMap { playlists[$0] }
    }

    /// The part of `body` a data request asked for, clamped to what exists.
    static func slice(_ body: Data, offset: Int64, length: Int) -> Data {
        let start = min(max(Int(clamping: offset), 0), body.count)
        let end = length < 0 ? body.count : min(start + length, body.count)
        return body.subdata(in: start..<end)
    }

    func resourceLoader(_ resourceLoader: AVAssetResourceLoader,
                        shouldWaitForLoadingOfRequestedResource request: AVAssetResourceLoadingRequest) -> Bool {
        guard let body = playlist(for: request.request.url) else { return false }
        request.contentInformationRequest?.describePlaylist(length: body.count)
        request.dataRequest?.respond(slicing: body)
        request.finishLoading()
        return true
    }
}

extension AVAssetResourceLoadingContentInformationRequest {
    func describePlaylist(length: Int) {
        contentType = "application/vnd.apple.mpegurl"
        contentLength = Int64(length)
        isByteRangeAccessSupported = true
    }
}

extension AVAssetResourceLoadingDataRequest {
    /// Hand back the part of `body` this request covers.
    func respond(slicing body: Data) {
        let length = requestsAllDataToEndOfResource ? -1 : requestedLength
        respond(with: HLSPlaylistLoader.slice(body, offset: requestedOffset, length: length))
    }
}
