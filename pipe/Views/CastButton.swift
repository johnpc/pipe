import SwiftUI

/// The cast affordance. When the Google Cast SDK is linked it embeds the SDK's
/// own `GCKUICastButton`, which shows the standard cast glyph, auto-hides when no
/// receiver is on the network, and presents the device picker itself. When the
/// SDK is absent (CI, or before the framework is added) it falls back to a plain
/// glyph that opens the picker via `CastStore` — a no-op there, but it keeps the
/// control (and its accessibility id) present so layout and tests stay stable.
struct CastButton: View {
    @ObservedObject var cast: CastStore

    var body: some View {
        content
            .accessibilityIdentifier("castButton")
            .accessibilityLabel("Cast to TV")
    }

    @ViewBuilder
    private var content: some View {
        #if canImport(GoogleCast)
        GCKCastButtonView()
            .frame(width: 24, height: 24)
        #else
        Button { cast.presentDevicePicker() } label: {
            Image(systemName: "tv.badge.wifi")
                .font(.title3)
        }
        .buttonStyle(.plain)
        #endif
    }
}

#if canImport(GoogleCast)
import GoogleCast

/// Bridges the UIKit `GCKUICastButton` into SwiftUI.
private struct GCKCastButtonView: UIViewRepresentable {
    func makeUIView(context: Context) -> GCKUICastButton {
        let button = GCKUICastButton(frame: CGRect(x: 0, y: 0, width: 24, height: 24))
        button.tintColor = .label
        return button
    }

    func updateUIView(_ uiView: GCKUICastButton, context: Context) {}
}
#endif
