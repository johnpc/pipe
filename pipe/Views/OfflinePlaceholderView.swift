import SwiftUI

/// Shown in place of a network-backed tab (Search) while Offline Mode is on.
/// Points the user at their Downloads, which still play without a connection.
struct OfflinePlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("You're Offline", systemImage: "wifi.slash")
        } description: {
            Text("Search needs a connection. Your downloads are available to play.")
        }
        .accessibilityIdentifier("offlinePlaceholder")
    }
}
