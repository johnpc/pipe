import SwiftUI

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
            Image(systemName: cast.hasDevices ? "tv.badge.wifi" : "tv.badge.wifi.searchlight")
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
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Make sure your TV is on the same Wi-Fi network as this iPhone.")
        }
    }
}
