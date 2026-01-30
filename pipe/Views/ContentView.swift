import SwiftUI

struct ContentView: View {
    @StateObject private var player = PlayerState()
    @StateObject private var following = FollowingStore()
    @StateObject private var recents = RecentsStore()
    @StateObject private var toast = ToastManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                Group {
                    switch selectedTab {
                    case 0:
                        NavigationStack {
                            SearchView(player: player, following: following)
                        }
                    case 1:
                        NavigationStack {
                            RecentsView(player: player, recents: recents)
                        }
                    case 2:
                        NavigationStack {
                            FollowingView(player: player, following: following)
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
                    
                    // Custom tab bar
                    HStack {
                        TabButton(icon: "magnifyingglass", label: "Search", isSelected: selectedTab == 0) { selectedTab = 0 }
                        TabButton(icon: "clock", label: "Recents", isSelected: selectedTab == 1) { selectedTab = 1 }
                        TabButton(icon: "heart.fill", label: "Following", isSelected: selectedTab == 2) { selectedTab = 2 }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 2)
                }
                .background(.bar)
            }
            
            // Toast overlay
            if let msg = toast.message {
                VStack {
                    Spacer()
                    ToastView(message: msg, isLoading: toast.isLoading)
                        .padding(.bottom, 120)
                }
                .animation(.easeInOut(duration: 0.2), value: toast.message)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear { player.recents = recents }
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
