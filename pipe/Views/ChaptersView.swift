import SwiftUI

/// Tappable list of a video's chapters; tapping seeks playback to that chapter.
struct ChaptersView: View {
    let chapters: [Chapter]
    let onSelect: (Chapter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Chapters").font(.headline)
            ForEach(chapters) { chapter in
                Button { onSelect(chapter) } label: {
                    HStack(spacing: 10) {
                        Text(formatTime(Double(chapter.start)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(width: 52, alignment: .leading)
                        Text(chapter.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("chapterRow")
            }
        }
    }
}
