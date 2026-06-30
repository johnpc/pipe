import SwiftUI

/// Toggle for SponsorBlock auto-skip in the full player. Highlights when active.
struct SponsorBlockToggle: View {
    @ObservedObject var player: PlayerState

    var body: some View {
        Button {
            player.sponsorBlockEnabled.toggle()
        } label: {
            Label("SponsorBlock", systemImage: player.sponsorBlockEnabled ? "forward.fill" : "forward")
                .font(.subheadline)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(player.sponsorBlockEnabled ? Color.orange : Color.secondary.opacity(0.2))
                .foregroundColor(player.sponsorBlockEnabled ? .white : .primary)
                .cornerRadius(20)
        }
        .accessibilityIdentifier("sponsorBlockToggle")
        .accessibilityValue(player.sponsorBlockEnabled ? "on" : "off")
    }
}
