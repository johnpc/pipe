import SwiftUI

/// Tappable list of a video's chapters; tapping seeks playback to that chapter.
struct ChaptersView: View {
    let chapters: [Chapter]
    /// Title of the chapter playing now, if this video is the one playing.
    var current: String? = nil
    let onSelect: (Chapter) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Chapters").font(.headline).padding(.bottom, 6)
            ForEach(chapters) { chapter in
                Button { onSelect(chapter) } label: { row(chapter, isCurrent: chapter.title == current) }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("chapterRow")
                    .accessibilityAddTraits(chapter.title == current ? .isSelected : [])
            }
        }
    }

    /// A 44-pt, full-width target; the playing chapter is tinted and bold.
    private func row(_ chapter: Chapter, isCurrent: Bool) -> some View {
        HStack(spacing: 12) {
            Text(formatTime(Double(chapter.start)))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(isCurrent ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                .frame(width: 56, alignment: .leading)
            Text(chapter.title)
                .font(isCurrent ? .subheadline.bold() : .subheadline)
                .lineLimit(1)
            Spacer()
            if isCurrent {
                Image(systemName: "speaker.wave.2.fill").font(.caption).foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 44)
        .background(isCurrent ? Color.accentColor.opacity(0.12) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
    }
}
