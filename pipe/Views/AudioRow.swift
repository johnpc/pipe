import SwiftUI

struct AudioRow: View {
    let item: SearchItem
    var isCompleted: Bool = false
    var resumeTime: Double? = nil
    var onPlay: (() -> Void)?
    var onQueue: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    AsyncImage(url: URL(string: item.displayThumbnail)) { $0.resizable().scaledToFill() } placeholder: { Color.gray }
                        .frame(width: 100, height: 56).clipped().cornerRadius(6)
                        .overlay(isCompleted ? Color.black.opacity(0.4).cornerRadius(6) : nil)
                    HStack(spacing: 4) {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                        if let d = item.duration, d > 0 {
                            Text(formatDuration(d))
                                .font(.caption2).bold()
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 4).padding(.vertical, 2)
                    .background(.black.opacity(0.7))
                    .cornerRadius(4)
                    .padding(4)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayUploader).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.tail)
                    if let date = item.uploadedDate {
                        Text(formatUploadDate(date)).font(.caption2).foregroundStyle(.tertiary)
                    }
                    if let time = resumeTime {
                        Label(formatTime(time), systemImage: "play.circle").font(.caption2).foregroundColor(.orange)
                    }
                }
                
                Spacer()
                
                if let onPlay {
                    Button { onPlay() } label: {
                        Image(systemName: "play.circle.fill").font(.title2)
                    }.buttonStyle(.plain)
                }
                if let onQueue {
                    Button { onQueue() } label: {
                        Image(systemName: "text.badge.plus").font(.title3)
                    }.buttonStyle(.plain)
                }
            }
            
            Text(item.displayTitle).font(.subheadline).lineLimit(3)
        }
        .padding(.vertical, 8)
    }
}

struct ChannelRow: View {
    let item: SearchItem
    
    var body: some View {
        HStack {
            AsyncImage(url: URL(string: item.displayThumbnail)) { $0.resizable() } placeholder: { Color.gray }
                .frame(width: 44, height: 44).clipShape(Circle())
            Text(item.displayTitle).font(.headline)
        }
    }
}
