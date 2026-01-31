import Foundation

let pipedBase = "https://pipedapi.jpc.io"

struct SearchItem: Codable, Identifiable, Hashable {
    let url: String
    let type: String
    let title: String?
    let thumbnail: String?
    let uploaderName: String?
    let uploaderUrl: String?
    let duration: Int?
    let name: String?
    let uploadedDate: String?
    
    var id: String { url }
    var isChannel: Bool { type == "channel" }
    var videoId: String { url.replacingOccurrences(of: "/watch?v=", with: "") }
    var channelId: String { url.replacingOccurrences(of: "/channel/", with: "") }
    var displayTitle: String { name ?? title ?? "Unknown" }
    var displayUploader: String { uploaderName ?? "" }
    var displayThumbnail: String { thumbnail ?? "" }
}

struct SearchResponse: Codable {
    let items: [SearchItem]
}

struct ChannelResponse: Codable {
    let id: String
    let name: String
    let avatarUrl: String?
    let description: String?
    let relatedStreams: [RelatedStream]
    let tabs: [ChannelTab]?
}

struct ChannelTab: Codable {
    let name: String
    let data: String
}

struct ChannelTabResponse: Codable {
    let content: [RelatedStream]
    let nextpage: String?
}

struct RelatedStream: Codable, Identifiable, Hashable {
    let url: String
    let title: String
    let thumbnail: String
    let duration: Int
    let uploaderName: String?
    let uploadedDate: String?
    let uploaded: Int64?
    
    var id: String { url }
    var videoId: String { url.replacingOccurrences(of: "/watch?v=", with: "") }
}

struct StreamResponse: Codable {
    let title: String
    let description: String?
    let uploader: String
    let uploaderUrl: String?
    let duration: Int
    let hls: String?
    let audioStreams: [AudioStream]
    let videoStreams: [VideoStream]
    let thumbnailUrl: String
    let uploadDate: String?
}

struct AudioStream: Codable {
    let url: String
    let bitrate: Int
    let mimeType: String
}

struct VideoStream: Codable {
    let url: String
    let quality: String
    let mimeType: String
    let videoOnly: Bool?
}

enum PipedAPI {
    static func search(_ query: String) async throws -> [SearchItem] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let url = URL(string: "\(pipedBase)/search?q=\(encoded)&filter=all")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(SearchResponse.self, from: data).items
    }
    
    static func channel(_ id: String) async throws -> ChannelResponse {
        let url = URL(string: "\(pipedBase)/channel/\(id)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ChannelResponse.self, from: data)
    }
    
    static func channelTab(_ tabData: String) async throws -> ChannelTabResponse {
        let encoded = tabData.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tabData
        let url = URL(string: "\(pipedBase)/channels/tabs?data=\(encoded)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(ChannelTabResponse.self, from: data)
    }
    
    static func streams(_ videoId: String) async throws -> StreamResponse {
        let url = URL(string: "\(pipedBase)/streams/\(videoId)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(StreamResponse.self, from: data)
    }
}
