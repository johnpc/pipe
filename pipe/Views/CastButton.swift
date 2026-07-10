import SwiftUI
import UIKit

/// The cast affordance: a pure-SwiftUI button (never the SDK's UIKit
/// `GCKUICastButton`, which crashes when hosted inside the full-player `.sheet`
/// on iOS 26 — see the crash-fix history). Because it renders identically in the
/// app and under UI tests, the acceptance test exercises the real shipped path.
///
/// When a receiver has been discovered, tapping opens the system Cast picker.
/// When none is found, tapping opens a "No TVs found" dialog with a Search-again
/// action rather than silently no-opping (`presentCastDialog()` does nothing with
/// no devices), so the control never feels dead.
struct CastButton: View {
    @ObservedObject var cast: CastStore
    @State private var showNoDevices = false

    var body: some View {
        Button {
            if cast.hasDevices {
                cast.presentDevicePicker()
            } else {
                showNoDevices = true
            }
        } label: {
            // Always a valid SF Symbol — an unknown name renders blank, which
            // silently makes the whole button invisible. "tv.badge.wifi" exists
            // on iOS; the no-devices state is conveyed by color, not a different
            // (and previously non-existent) glyph.
            Image(systemName: "tv.badge.wifi")
                .font(.title3)
                .foregroundStyle(cast.hasDevices ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("castButton")
        .accessibilityLabel(cast.hasDevices ? "Cast to TV" : "No TVs found")
        .confirmationDialog("No TVs found",
                            isPresented: $showNoDevices,
                            titleVisibility: .visible) {
            Button("Search Again") { cast.rescan() }
            Button("Open Settings") { openSettings() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Make sure your TV is on the same Wi-Fi network, and that pipe has Local Network access (Settings → pipe → Local Network) — without it iOS silently hides all Cast devices.")
        }
    }

    /// Deep-link to pipe's iOS Settings page, where the Local Network toggle
    /// lives — the most common silent cause of "no devices found".
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
