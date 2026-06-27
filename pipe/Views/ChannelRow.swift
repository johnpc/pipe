import SwiftUI

/// A channel search result: avatar, name with a verified badge, and a compact
/// subscriber count.
struct ChannelRow: View {
    let item: SearchItem

    var body: some View {
        HStack {
            AsyncImage(url: URL(string: item.displayThumbnail)) { $0.resizable() } placeholder: { Color.gray }
                .frame(width: 44, height: 44).clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(item.displayTitle).font(.headline)
                    if item.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption).foregroundStyle(.secondary)
                            .accessibilityLabel("Verified")
                    }
                }
                if let subs = item.subscriberText {
                    Text(subs).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
