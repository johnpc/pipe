import SwiftUI

/// Attaches diagnostic logging for navigation + app-lifecycle to the root view,
/// keeping ContentView focused on layout. Logs tab changes, Settings open/close,
/// offline-mode toggles, and scene-phase transitions (flushing on background).
struct DiagnosticsLogging: ViewModifier {
    @ObservedObject var player: PlayerState
    let selectedTab: Int
    let showSettings: Bool
    let offlineMode: Bool
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .onChange(of: selectedTab) { _, tab in
                player.log.event("nav", "tab", fields: ["index": String(tab)])
            }
            .onChange(of: showSettings) { _, shown in
                player.log.event("nav", shown ? "openSettings" : "closeSettings")
            }
            .onChange(of: offlineMode) { _, isOffline in
                player.log.event("nav", "offlineMode", fields: ["on": String(isOffline)])
            }
            .onChange(of: scenePhase) { _, phase in
                player.log.event("lifecycle", "\(phase)", fields: ["playing": String(player.isPlaying)])
                // Backgrounding is a natural session boundary — get logs off-device.
                if phase != .active { player.log.flush() }
            }
    }
}

extension View {
    func diagnosticsLogging(player: PlayerState, selectedTab: Int, showSettings: Bool, offlineMode: Bool) -> some View {
        modifier(DiagnosticsLogging(player: player, selectedTab: selectedTab,
                                    showSettings: showSettings, offlineMode: offlineMode))
    }
}
