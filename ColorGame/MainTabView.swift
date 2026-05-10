import SwiftUI

struct MainTabView: View {
  @StateObject private var leaderboardStore = LeaderboardStore.shared
  @State private var selectedTab = 0

  var body: some View {
    VStack(spacing: 0) {
      ZStack {
        HomeView()
          .opacity(selectedTab == 0 ? 1 : 0)
          .allowsHitTesting(selectedTab == 0)
        LeaderboardView()
          .opacity(selectedTab == 1 ? 1 : 0)
          .allowsHitTesting(selectedTab == 1)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      CRTabBar(
        items: [
          CRTabBarItem(
            id: 0,
            icon: Image(systemName: "house.fill"),
            selectedTint: Theme.Colors.accent,
            accessibilityLabel: "Home"
          ),
          CRTabBarItem(
            id: 1,
            icon: Image(systemName: "trophy.fill"),
            selectedTint: Theme.Colors.pro,
            accessibilityLabel: "Leaderboard"
          ),
        ],
        selection: $selectedTab
      )
    }
    .background(Theme.Colors.background.ignoresSafeArea())
    .onReceive(NotificationCenter.default
      .publisher(for: NSNotification.Name("SwitchToLeaderboard")))
    { _ in
      selectedTab = 1
    }
  }
}
