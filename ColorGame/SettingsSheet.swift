import SwiftUI

struct SettingsSheet: View {
  @AppStorage("cr.appVolume") private var appVolume: Double = 1.0
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @State private var isRestoring = false

  var body: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.xl) {
      header

      VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        volumeSection
        if appVolume == 0 {
          muteWarning
        }
      }

      Spacer(minLength: Theme.Spacing.xl)

      footerActions
    }
    .padding(Theme.Spacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(Theme.Colors.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
  }

  private var header: some View {
    HStack {
      Text("Settings")
        .font(.crHeadlineUpright)
        .foregroundStyle(Theme.Colors.textPrimary)
      Spacer()
      Button {
        dismiss()
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 16, weight: .bold))
      }
      .buttonStyle(.crIcon)
    }
  }

  private var volumeSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      Text("Volume")
        .font(.crLabelUpright)
        .textCase(.uppercase)
        .foregroundStyle(Theme.Colors.textSecondary)
      Slider(value: $appVolume, in: 0 ... 1) {
        Text("Volume")
      } onEditingChanged: { editing in
        if !editing {
          LogService.shared.log("settings_volume_changed", ["value": appVolume])
        }
      }
      .tint(Theme.Colors.accentSecondary)
    }
  }

  private var muteWarning: some View {
    HStack(alignment: .top, spacing: Theme.Spacing.sm) {
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.system(size: 14, weight: .bold))
        .foregroundStyle(Theme.Colors.warning)
      Text("Sound is needed to play — the called color is announced out loud.")
        .font(.crCaptionUpright)
        .foregroundStyle(Theme.Colors.warning)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(Theme.Spacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(
      RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        .fill(Theme.Colors.surface)
    )
  }

  private var footerActions: some View {
    VStack(alignment: .leading, spacing: 0) {
      Rectangle()
        .fill(Theme.Colors.border)
        .frame(height: 1)
        .padding(.bottom, Theme.Spacing.md)

      Button(action: triggerRestore) {
        HStack(spacing: Theme.Spacing.sm) {
          if isRestoring {
            ProgressView()
              .progressViewStyle(.circular)
              .tint(Theme.Colors.textSecondary)
          }
          Text("Restore Purchases")
            .font(.crBodyUpright)
            .foregroundStyle(Theme.Colors.textPrimary)
          Spacer(minLength: 0)
        }
        .padding(.vertical, Theme.Spacing.md)
      }
      .disabled(isRestoring)

      Button(action: openLegal) {
        Text("Legal")
          .font(.crBodyUpright)
          .foregroundStyle(Theme.Colors.textPrimary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.vertical, Theme.Spacing.md)
      }
    }
  }

  private func triggerRestore() {
    guard !isRestoring else { return }
    SoundService.shared.play(.secondary)
    LogService.shared.log("settings_restore_pressed")
    isRestoring = true
    let store = StoreService.shared
    Task {
      defer { isRestoring = false }
      do {
        try await store.restore()
        await MainActor.run {
          LogService.shared.log("restore_completed", [
            "hasRemoveAds": store.hasRemoveAds,
          ])
        }
      } catch {
        await MainActor.run {
          LogService.shared.error("restore_failed", ["error": String(describing: error)])
        }
      }
    }
  }

  private func openLegal() {
    SoundService.shared.play(.secondary)
    let locale = Bundle.main.preferredLocalizations.first ?? "en"
    let normalized = locale.hasPrefix("fr") ? "fr" : "en"
    LogService.shared.log("settings_legal_pressed", ["locale": normalized])
    if let url = URL(string: "https://nicode.bichu.fr/?lang=\(normalized)#privacy") {
      openURL(url)
    }
  }
}

#Preview {
  SettingsSheet()
}
