import SwiftUI

struct MainTabView: View {
    @StateObject private var leaderboardStore = LeaderboardStore.shared
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            LeaderboardView()
                .tabItem {
                    Image(systemName: "trophy.fill")
                    Text("Leaderboard")
                }
                .tag(1)
        }
        .accentColor(.purple)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToLeaderboard"))) { _ in
            selectedTab = 1
        }
    }
}
