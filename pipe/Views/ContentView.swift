import SwiftUI

struct ContentView: View {
    @StateObject private var player = PlayerState()
    @StateObject private var following = FollowingStore()
    @StateObject private var recents = RecentsStore()
    @StateObject private var settings = AppSettings()
    @StateObject private var saved = SavedStore()
    @StateObject private var downloads = DownloadStore()
    @StateObject private var toast = ToastManager.shared
    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            MainTabContent(selectedTab: selectedTab, player: player, following: following,
                           recents: recents, settings: settings, saved: saved, downloads: downloads)

            // Unified bottom bar
            VStack(spacing: 0) {
                if player.currentTitle != nil {
                    MiniPlayerBar(player: player)
                }

                BottomTabBar(selectedTab: $selectedTab) { showSettings = true }
            }
            .background(.bar)
        }
        .toastOverlay()
        .onAppear {
            player.recents = recents; player.downloads = downloads
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
    }
}
