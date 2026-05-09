//
//  HomeView.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import RevenueCat
import SwiftUI

enum Difficulty: String, CaseIterable {
  case easy = "Easy"
  case normal = "Normal"
  case hard = "Hard"
}

struct HomeView: View {
  @State private var isLevelSystemSelectionPresented = false
  @StateObject private var leaderboardStore = LeaderboardStore.shared
  @StateObject private var store = StoreService.shared
  @State private var isPurchasing = false
  @State private var isRestoring = false

  var body: some View {
    ZStack {
      Theme.Colors.background
        .ignoresSafeArea()

      VStack(spacing: 0) {
        bestScoreHeader
          .padding(.horizontal, Theme.Spacing.xl)
          .padding(.top, Theme.Spacing.lg)

        Spacer(minLength: Theme.Spacing.xxl)

        logo

        Spacer().frame(height: Theme.Spacing.xl)

        tagline
          .padding(.horizontal, Theme.Spacing.xl)

        Spacer(minLength: Theme.Spacing.xxxl)

        playButton

        Spacer(minLength: Theme.Spacing.xl)

        if !store.hasRemoveAds {
          iapFooter
            .padding(.horizontal, Theme.Spacing.xl)
        }

        Spacer().frame(height: Theme.Spacing.xl)
      }
    }
    .preferredColorScheme(.dark)
    #if !os(macOS)
    .fullScreenCover(isPresented: $isLevelSystemSelectionPresented) {
      LevelSystemSelectionView(isPresented: $isLevelSystemSelectionPresented)
    }
    .onReceive(NotificationCenter.default
      .publisher(for: NSNotification.Name("SwitchToLeaderboard")))
    { _ in
      isLevelSystemSelectionPresented = false
    }
    .onReceive(NotificationCenter.default
      .publisher(for: NSNotification.Name("DismissToHome")))
    { _ in
      isLevelSystemSelectionPresented = false
    }
    #else
    .sheet(isPresented: $isLevelSystemSelectionPresented) {
      LevelSystemSelectionView(isPresented: $isLevelSystemSelectionPresented)
    }
    #endif
  }

  // MARK: Sections

  private var bestScoreHeader: some View {
    HStack {
      VStack(alignment: .leading, spacing: 0) {
        Text("BEST")
          .font(.crLabel)
          .textCase(.uppercase)
          .foregroundStyle(Theme.Colors.textSecondary)
        Text(currentBestScore)
          .font(.crHeadline)
          .foregroundStyle(Theme.Colors.pro)
      }
      Spacer()
    }
  }

  private var logo: some View {
    Image("CRLogo")
      .resizable()
      .scaledToFit()
      .frame(maxWidth: 280)
      .accessibilityLabel("Color Rush")
  }

  private var tagline: some View {
    (
      Text("A color is called.\nTap ").foregroundStyle(Theme.Colors.textPrimary)
        + Text("everything else.").foregroundStyle(Theme.Colors.accentSecondary)
    )
    .font(.crTitle)
    .multilineTextAlignment(.leading)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var playButton: some View {
    Button {
      isLevelSystemSelectionPresented = true
    } label: {
      HStack(spacing: Theme.Spacing.md) {
        Image(systemName: "play.fill")
          .font(.system(size: 56, weight: .bold))
        Text("Play")
          .font(.crTitle)
      }
    }
    .buttonStyle(.crPrimaryCircular)
  }

  private var iapFooter: some View {
    VStack(spacing: Theme.Spacing.md) {
      Button(action: triggerPurchase) {
        HStack(spacing: Theme.Spacing.sm) {
          if isPurchasing {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(Theme.Colors.textPrimary)
          } else {
            Image(systemName: "sparkles")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(Theme.Colors.accentSecondary)
          }
          Text(removeAdsButtonTitle)
            .font(.crCaption)
            .foregroundStyle(Theme.Colors.textPrimary)
        }
        .padding(.vertical, Theme.Spacing.md - 2)
        .padding(.horizontal, Theme.Spacing.lg)
        .background(
          Capsule(style: .continuous)
            .fill(Theme.Colors.surfaceElevated)
        )
      }
      .disabled(store.package == nil || isPurchasing || isRestoring)
      .opacity(store.package == nil ? 0.6 : 1)

      Button(action: triggerRestore) {
        HStack(spacing: Theme.Spacing.xs) {
          if isRestoring {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(Theme.Colors.textSecondary)
          }
          Text("Restore Purchases")
            .font(.crCaption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .underline()
        }
      }
      .disabled(isPurchasing || isRestoring)
    }
  }

  // MARK: Derived state

  private var currentBestScore: String {
    let score = leaderboardStore.getOverallBestScore()
    return score > 0 ? "\(score)" : "—"
  }

  private var removeAdsButtonTitle: LocalizedStringKey {
    if let package = store.package {
      "Remove Ads — \(package.storeProduct.localizedPriceString)"
    } else {
      "Loading…"
    }
  }

  // MARK: Actions

  private func triggerPurchase() {
    guard !isPurchasing else { return }
    isPurchasing = true
    Task {
      defer { isPurchasing = false }
      do {
        _ = try await store.purchase()
      } catch {
        print("Purchase failed: \(error)")
      }
    }
  }

  private func triggerRestore() {
    guard !isRestoring else { return }
    isRestoring = true
    Task {
      defer { isRestoring = false }
      do {
        try await store.restore()
      } catch {
        print("Restore failed: \(error)")
      }
    }
  }
}

#Preview {
  HomeView()
}
