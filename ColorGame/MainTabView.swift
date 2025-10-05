import SwiftUI

struct MainTabView: View {
    @StateObject private var leaderboardStore = LeaderboardStore.shared
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            LeaderboardView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Leaderboard")
                }
        }
        .accentColor(.purple)
    }
}
