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

            Button {
                // Always emit a marker so a tap is visible server-side even when
                // nothing else happened, then force an immediate upload.
                log.event("diagnostics", "send logs tapped", fields: ["uploadOn": String(settings.diagnosticsUpload)])
                log.flush()
            } label: {
                Label("Send Logs Now", systemImage: "paperplane")
            }
            .accessibilityIdentifier("sendLogsNow")

            Button(role: .destructive) {
                log.buffer.clear()
            } label: {
                Label("Clear Playback Log", systemImage: "trash")
            }
            .accessibilityIdentifier("clearPlaybackLog")
        } header: {
            Text("Diagnostics")
        } footer: {
            Text("Capture playback issues, then Send Logs (if upload is on) or Share them so they can be diagnosed.")
        }
        .sheet(isPresented: Binding(get: { shareText != nil }, set: { if !$0 { shareText = nil } })) {
            if let shareText {
                ShareSheet(items: [shareText])
            }
        }
    }
}
