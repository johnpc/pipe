import SwiftUI
import UIKit

/// Settings section that exposes the on-device diagnostic playback log so a user
/// can share it (AirDrop / Messages / Files) after reproducing a playback bug —
/// no data leaves the device unless they explicitly share it.
struct DiagnosticsSection: View {
    @ObservedObject var settings: AppSettings
    var log: PlaybackLog = .shared
    @State private var shareText: String?

    var body: some View {
        Section {
            Toggle("Upload Diagnostics", isOn: $settings.diagnosticsUpload)
                .accessibilityIdentifier("diagnosticsUploadToggle")

            Button {
                shareText = log.exportText()
            } label: {
                Label("Share Playback Log", systemImage: "square.and.arrow.up")
            }
            .accessibilityIdentifier("sharePlaybackLog")

            Button(role: .destructive) {
                log.buffer.clear()
            } label: {
                Label("Clear Playback Log", systemImage: "trash")
            }
            .accessibilityIdentifier("clearPlaybackLog")
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("Capture playback issues, then share this log so they can be diagnosed.")
        }
        .sheet(isPresented: Binding(get: { shareText != nil }, set: { if !$0 { shareText = nil } })) {
            if let shareText {
                ShareSheet(items: [shareText])
            }
        }
    }
}

/// Minimal UIActivityViewController wrapper for sharing the exported log text.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
