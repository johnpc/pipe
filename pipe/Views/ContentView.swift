import SwiftUI

struct ContentView: View {
    @StateObject private var player = PlayerState()
    @StateObject private var following = FollowingStore()
    @StateObject private var recents = RecentsStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var saved = SavedStore()
    @StateObject private var downloads = DownloadStore()
    @StateObject private var cast = CastStore()
    @StateObject private var toast = ToastManager.shared
    @State private var selectedTab = 0
    @State private var showSettings = false
    @State private var columns: NavigationSplitViewVisibility = .all
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        Group {
            if sizeClass == .regular { splitLayout } else { compactLayout }
        }
        .toastOverlay()
        .onAppear {
            player.recents = recents; player.downloads = downloads
            player.attachCast(cast)
            // Attach the remote sink BEFORE the session-start event so the event
            // (which records the configured Piped instance) is actually uploaded
            // — otherwise it only ever lands in the on-device buffer.
            player.syncDiagnosticsUpload(enabled: settings.diagnosticsUpload)
            player.logSessionStart(instance: settings.instanceURL)
        }
        .onChange(of: settings.diagnosticsUpload) { _, on in
            player.syncDiagnosticsUpload(enabled: on)
        }
        .onChange(of: player.error) { _, newError in
            if let msg = newError {
                player.log.event("error", "surfaced", fields: ["message": msg])
                toast.showError(msg)
                player.error = nil
            }
        }
        .onChange(of: settings.offlineMode) { _, isOffline in
            // Enabling offline mode drops the user on the home tab so they land
            // on Downloads instead of a now-empty network tab.
            if isOffline { selectedTab = OfflineLogic.homeTab }
        }
        .diagnosticsLogging(player: player, selectedTab: selectedTab,
                            showSettings: showSettings, offlineMode: settings.offlineMode)
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(settings: settings, player: player, recents: recents) { showSettings = false }
            }
        }
    }
}

private extension ContentView {
    var content: MainTabContent {
        MainTabContent(selectedTab: selectedTab, player: player, following: following,
                       recents: recents, settings: settings, saved: saved, downloads: downloads)
    }

    /// Phone: content over a unified bottom bar (mini player + tabs).
    var compactLayout: some View {
        VStack(spacing: 0) {
            content
            VStack(spacing: 0) {
                if player.currentTitle != nil {
                    MiniPlayerBar(player: player)
                }
                BottomTabBar(selectedTab: $selectedTab) { showSettings = true }
            }
            .background(.bar)
        }
    }

    /// iPad: sidebar navigation, content column with the mini player docked
    /// beneath it — the phone bar stretched across 13 inches read as a toy.
    var splitLayout: some View {
        NavigationSplitView(columnVisibility: $columns) {
            SidebarView(selectedTab: $selectedTab) { showSettings = true }
        } detail: {
            VStack(spacing: 0) {
                content
                if player.currentTitle != nil {
                    MiniPlayerBar(player: player).background(.bar)
                }
            }
        }
    }
}

struct TabButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
        }
        // Stable id for UI tests: the label alone collides with other controls
        // (the search field's own "Search" button).
        .accessibilityIdentifier("tab-\(label)")
    }
}
