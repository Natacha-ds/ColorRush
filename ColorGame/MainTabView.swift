import SwiftUI

struct MainTabView: View {
  @StateObject private var leaderboardStore = LeaderboardStore.shared
  @State private var selectedTab = 0
  @Environment(\.openURL) private var openURL

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

      legalFooter

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

  /// Tiny privacy / legal link sitting just above the tab bar. Visible on
  /// every tab so it never disappears with Remove Ads or screen change.
  private var legalFooter: some View {
    Button {
      SoundService.shared.play(.secondary)
      let locale = Bundle.main.preferredLocalizations.first ?? "en"
      let normalized = locale.hasPrefix("fr") ? "fr" : "en"
      LogService.shared.log("legal_link_pressed", ["locale": normalized])
      if let url = URL(
        string: "https://nicode.bichu.fr/?lang=\(normalized)#privacy"
      ) {
        openURL(url)
      }
    } label: {
      Text("Legal")
        .font(.crCaptionUpright)
        .foregroundStyle(Theme.Colors.textMuted)
        .underline()
    }
  }
}
