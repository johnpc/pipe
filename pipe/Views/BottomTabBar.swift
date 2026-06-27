import SwiftUI

/// The custom bottom tab bar — four primary destinations plus a Settings gear.
/// Extracted from ContentView to keep that file declarative and under the limit.
struct BottomTabBar: View {
    @Binding var selectedTab: Int
    let onSettings: () -> Void

    var body: some View {
        HStack {
            TabButton(icon: "rectangle.stack", label: "Feed", isSelected: selectedTab == 0) { selectedTab = 0 }
            TabButton(icon: "magnifyingglass", label: "Search", isSelected: selectedTab == 1) { selectedTab = 1 }
            TabButton(icon: "clock", label: "Recents", isSelected: selectedTab == 2) { selectedTab = 2 }
            TabButton(icon: "heart.fill", label: "Following", isSelected: selectedTab == 3) { selectedTab = 3 }
            TabButton(icon: "gearshape", label: "Settings", isSelected: false, action: onSettings)
                .accessibilityIdentifier("Settings")
        }
        .padding(.top, 8)
        .padding(.bottom, 2)
    }
}
