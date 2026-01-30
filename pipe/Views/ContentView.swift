import SwiftUI

struct ContentView: View {
    @StateObject private var player = PlayerState()
    @StateObject private var following = FollowingStore()
    
    var body: some View {
        TabView {
            NavigationStack {
                SearchView(player: player, following: following)
            }
            .tabItem { Label("Search", systemImage: "magnifyingglass") }
            
            NavigationStack {
                FollowingView(player: player, following: following)
            }
            .tabItem { Label("Following", systemImage: "heart.fill") }
        }
        .safeAreaInset(edge: .bottom) {
            if player.currentTitle != nil {
                MiniPlayerBar(player: player).padding(.bottom, 49)
            }
        }
    }
}
