import SwiftUI

/// The cast affordance: a plain SwiftUI button that opens the system Cast device
/// picker via `CastStore`.
///
/// We deliberately do NOT embed the SDK's `GCKUICastButton` (a UIKit view). Doing
/// so inside the full-player `.sheet` crashed on iOS 26 — SwiftUI's out-of-process
/// sheet presentation fails a dynamic cast on the hosted UIKit control
/// (`RemoteSheetContainerVCWriter` → `swift_dynamicCast` → fatalError). A pure
/// SwiftUI button sidesteps that entirely, and — since it renders the same in the
/// app and under UI tests — the acceptance test exercises the real shipped path.
struct CastButton: View {
    @ObservedObject var cast: CastStore

    var body: some View {
        Button { cast.presentDevicePicker() } label: {
            Image(systemName: "tv.badge.wifi").font(.title3)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("castButton")
        .accessibilityLabel("Cast to TV")
    }
}
