import SwiftUI

/// One destination in the iPad sidebar. The tab index matches `BottomTabBar`
/// so both shells drive the same `MainTabContent`.
struct SidebarItem: Identifiable, Equatable {
    let tab: Int
    let label: String
    let icon: String
    var id: Int { tab }

    static let primary = [
        SidebarItem(tab: 0, label: "Feed", icon: "rectangle.stack"),
        SidebarItem(tab: 1, label: "Search", icon: "magnifyingglass"),
        SidebarItem(tab: 2, label: "Recents", icon: "clock"),
        SidebarItem(tab: 3, label: "Following", icon: "heart.fill"),
    ]
}

/// The regular-width (iPad) navigation: a sidebar in place of the phone's
/// bottom tab bar. Rows keep the `tab-<Name>` identifiers the UI tests use.
struct SidebarView: View {
    @Binding var selectedTab: Int
    let onSettings: () -> Void

    private var selection: Binding<Int?> {
        Binding(get: { selectedTab }, set: { if let tab = $0 { selectedTab = tab } })
    }

    var body: some View {
        List(selection: selection) {
            Section {
                ForEach(SidebarItem.primary) { item in
                    Label(item.label, systemImage: item.icon)
                        .tag(item.tab)
                        .accessibilityIdentifier("tab-\(item.label)")
                }
            }
            Section {
                Button(action: onSettings) {
                    Label("Settings", systemImage: "gearshape")
                }
                .accessibilityIdentifier("tab-Settings")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("pipe")
    }
}
