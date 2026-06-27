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
        ZStack {
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 0:
                        NavigationStack {
                            FeedView(player: player, following: following, recents: recents, saved: saved, downloads: downloads)
                        }
                    case 1:
                        NavigationStack {
                            SearchView(player: player, following: following, recents: recents, settings: settings, saved: saved, downloads: downloads)
                        }
                    case 2:
                        NavigationStack {
                            RecentsView(player: player, recents: recents)
                        }
                    case 3:
                        NavigationStack {
                            FollowingView(player: player, following: following, recents: recents)
                        }
                    default:
                        EmptyView()
                    }
                }
                
                // Unified bottom bar
                VStack(spacing: 0) {
                    if player.currentTitle != nil {
                        MiniPlayerBar(player: player)
                    }
                    
                    BottomTabBar(selectedTab: $selectedTab) { showSettings = true }
                }
                .background(.bar)
            }
            
            // Toast overlay
            if let msg = toast.message {
                VStack {
                    Spacer()
                    ToastView(message: msg, isLoading: toast.isLoading, isError: toast.isError)
                        .padding(.bottom, 120)
                }
                .animation(.easeInOut(duration: 0.2), value: toast.message)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { player.recents = recents; player.downloads = downloads }
        .onChange(of: player.error) { _, newError in
            if let msg = newError {
                toast.showError(msg)
                player.error = nil
            }
        }
        .sheet(isPresented: $showSettings) {
            NavigationStack {
                SettingsView(settings: settings, player: player, recents: recents)
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
