import SwiftUI

/// The row's thumbnail, title, and channel, shown on a detail page that has no
/// stream to describe itself with (not started yet, or not available).
struct DetailPreviewHeader: View {
    let preview: DetailPreview

    var body: some View {
        HStack(alignment: .top) {
            AsyncImage(url: URL(string: preview.thumbnail)) { $0.resizable() } placeholder: { Color.gray }
                .frame(width: 100, height: 100).cornerRadius(8)
            VStack(alignment: .leading, spacing: 8) {
                Text(preview.title).font(.headline)
                if !preview.uploader.isEmpty {
                    Text(preview.uploader).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

/// A premiere or scheduled stream that has not started: say when, offer nothing
/// to play, and let the viewer check again (the start may have passed).
struct UpcomingDetailView: View {
    let preview: DetailPreview?
    let start: Date?
    let message: String?
    let onCheckAgain: () -> Void

    private var headline: String {
        start.map { "Premieres " + UploadDateFormat.scheduled($0, now: Date(), timeZone: .current, locale: .current) } ?? "Hasn't started yet"
    }

    var body: some View {
        VStack(spacing: 0) {
            if let preview { DetailPreviewHeader(preview: preview) }
            ContentUnavailableView {
                Label(headline, systemImage: "clock")
                    .accessibilityIdentifier("detailPremiere")
            } description: {
                Text(message ?? "There's nothing to play until it starts. Come back then.")
            } actions: {
                Button("Check again", action: onCheckAgain).buttonStyle(.bordered)
                    .accessibilityIdentifier("checkAgainButton")
            }
        }
    }
}

/// A video the instance cannot serve at all (private, removed, region- or
/// age-locked, members-only). No Retry — it would not help — but the YouTube
/// link stays, since the viewer may be able to watch it there.
struct UnavailableDetailView: View {
    let preview: DetailPreview?
    let message: String
    let videoId: String

    var body: some View {
        VStack(spacing: 0) {
            if let preview { DetailPreviewHeader(preview: preview) }
            ContentUnavailableView {
                Label("Not available", systemImage: "video.slash")
                    .accessibilityIdentifier("detailUnavailable")
            } description: {
                Text(message)
            } actions: {
                if let url = RowActions.youtubeURL(videoId: videoId) {
                    Link("Open on YouTube", destination: url).buttonStyle(.bordered)
                }
            }
        }
    }
}
