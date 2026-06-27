import SwiftUI

/// Reusable "couldn't load" state with a Retry button, so the network
/// resilience layer's failures are visible to the user instead of an endless
/// spinner.
struct RetryView: View {
    var message: String = "Couldn't load. Check your connection or Piped instance."
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Something went wrong", systemImage: "wifi.exclamationmark")
        } description: {
            Text(message)
        } actions: {
            Button("Retry", action: onRetry)
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("retryButton")
        }
    }
}
