//
//  DesignSystemPreview.swift
//  ColorRush
//
//  Living showcase of every design token and shared component.
//  Use as Xcode preview during the redesign or as a runtime debug screen.
//

import SwiftUI

#if DEBUG

struct DesignSystemPreview: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
        section("Colors") {
          colorSwatches
        }
        section("Tile colors") {
          tileSwatchGrid
        }
        section("Gradients") {
          gradientSwatches
        }
        section("Typography") {
          typographyScale
        }
        section("Spacing") {
          spacingRulers
        }
        section("Radii") {
          radiusSamples
        }
        section("Buttons") {
          buttonsSection
        }
        section("Components") {
          componentsSection
        }
        section("Tab bar") {
          tabBarSection
        }
      }
      .padding(Theme.Spacing.xl)
    }
    .background(Theme.Colors.background.ignoresSafeArea())
    .preferredColorScheme(.dark)
  }

  // MARK: Tab bar (stateful demo)

  private var tabBarSection: some View {
    TabBarPreviewRow()
  }

  private struct TabBarPreviewRow: View {
    @State private var selection: Int = 0
    var body: some View {
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
        selection: $selection
      )
      .background(Theme.Colors.background)
    }
  }

  // MARK: Section helper

  @ViewBuilder
  private func section<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
      Text(title)
        .font(.crHeadline)
        .textCase(.uppercase)
        .foregroundStyle(Theme.Colors.textPrimary)
      content()
    }
  }

  // MARK: Colors

  private struct ColorSwatch: Identifiable {
    let id = UUID()
    let name: String
    let color: Color
  }

  private var swatches: [ColorSwatch] {
    [
      .init(name: "background", color: Theme.Colors.background),
      .init(name: "surface", color: Theme.Colors.surface),
      .init(name: "surfaceElevated", color: Theme.Colors.surfaceElevated),
      .init(name: "border", color: Theme.Colors.border),
      .init(name: "borderStrong", color: Theme.Colors.borderStrong),
      .init(name: "textPrimary", color: Theme.Colors.textPrimary),
      .init(name: "textSecondary", color: Theme.Colors.textSecondary),
      .init(name: "textMuted", color: Theme.Colors.textMuted),
      .init(name: "accent", color: Theme.Colors.accent),
      .init(name: "accentSecondary", color: Theme.Colors.accentSecondary),
      .init(name: "success", color: Theme.Colors.success),
      .init(name: "warning", color: Theme.Colors.warning),
      .init(name: "danger", color: Theme.Colors.danger),
      .init(name: "pro", color: Theme.Colors.pro),
    ]
  }

  private var tileSwatches: [ColorSwatch] {
    [
      .init(name: "system.red", color: .red),
      .init(name: "system.blue", color: .blue),
      .init(name: "system.green", color: .green),
      .init(name: "system.yellow", color: .yellow),
    ]
  }

  private var colorSwatches: some View {
    swatchGrid(swatches)
  }

  private var tileSwatchGrid: some View {
    swatchGrid(tileSwatches, height: 72, columnMinimum: 80)
  }

  private func swatchGrid(
    _ items: [ColorSwatch],
    height: CGFloat = 56,
    columnMinimum: CGFloat = 100
  ) -> some View {
    LazyVGrid(
      columns: [GridItem(.adaptive(minimum: columnMinimum), spacing: Theme.Spacing.sm)],
      spacing: Theme.Spacing.sm
    ) {
      ForEach(items) { swatch in
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
          RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
            .fill(swatch.color)
            .frame(height: height)
            .overlay(
              RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                .strokeBorder(Theme.Colors.border, lineWidth: 1)
            )
          Text(swatch.name)
            .font(.crCaption)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
      }
    }
  }

  // MARK: Gradients

  private var gradientSwatches: some View {
    VStack(spacing: Theme.Spacing.sm) {
      gradientRow("primary", gradient: Theme.Gradient.primary)
      gradientRow("danger", gradient: Theme.Gradient.danger)
      gradientRow("progress", gradient: Theme.Gradient.progress)
      gradientRow("logo", gradient: Theme.Gradient.logo)
    }
  }

  private func gradientRow(_ name: String, gradient: LinearGradient) -> some View {
    HStack(spacing: Theme.Spacing.md) {
      Text(name)
        .font(.crCaption)
        .foregroundStyle(Theme.Colors.textSecondary)
        .frame(width: 80, alignment: .leading)
      RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
        .fill(gradient)
        .frame(height: 32)
    }
  }

  // MARK: Typography

  private struct TypeSpec: Identifiable {
    let id = UUID()
    let name: String
    let font: Font
    let sample: String
  }

  private var typeSpecs: [TypeSpec] {
    [
      .init(name: "crScoreHero", font: .crScoreHero, sample: "260"),
      .init(name: "crLogo", font: .crLogo, sample: "COLOR RUSH"),
      .init(name: "crDisplay", font: .crDisplay, sample: "BEAT 250"),
      .init(name: "crTitle", font: .crTitle, sample: "LEVEL 01"),
      .init(name: "crHeadline", font: .crHeadline, sample: "PICK A MODE"),
      .init(name: "crButtonLabel", font: .crButtonLabel, sample: "PLAY"),
      .init(name: "crBody", font: .crBody, sample: "A color is called. Tap everything else."),
      .init(name: "crLabel", font: .crLabel, sample: "TARGET"),
      .init(name: "crCaption", font: .crCaption, sample: "5 lives — good to start"),
      .init(name: "crPill", font: .crPill, sample: "RECOMMENDED TO START"),
    ]
  }

  private var typographyScale: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      ForEach(typeSpecs) { spec in
        VStack(alignment: .leading, spacing: 2) {
          Text(spec.name)
            .font(.crCaption)
            .foregroundStyle(Theme.Colors.textSecondary)
          Text(spec.sample)
            .font(spec.font)
            .foregroundStyle(Theme.Colors.textPrimary)
        }
      }
    }
  }

  // MARK: Spacing

  private var spacingValues: [(name: String, value: CGFloat)] {
    [
      ("xs", Theme.Spacing.xs),
      ("sm", Theme.Spacing.sm),
      ("md", Theme.Spacing.md),
      ("lg", Theme.Spacing.lg),
      ("xl", Theme.Spacing.xl),
      ("xxl", Theme.Spacing.xxl),
      ("xxxl", Theme.Spacing.xxxl),
    ]
  }

  private var spacingRulers: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
      ForEach(spacingValues, id: \.name) { spec in
        HStack(spacing: Theme.Spacing.md) {
          Text("\(spec.name) · \(Int(spec.value))pt")
            .font(.crCaption)
            .foregroundStyle(Theme.Colors.textSecondary)
            .frame(width: 100, alignment: .leading)
          RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Theme.Colors.accent)
            .frame(width: spec.value, height: 16)
        }
      }
    }
  }

  // MARK: Radii

  private var radiusValues: [(name: String, value: CGFloat)] {
    [
      ("sm", Theme.Radius.sm),
      ("md", Theme.Radius.md),
      ("lg", Theme.Radius.lg),
      ("xl", Theme.Radius.xl),
      ("pill", 28), // visual only
    ]
  }

  private var radiusSamples: some View {
    HStack(spacing: Theme.Spacing.md) {
      ForEach(radiusValues, id: \.name) { spec in
        VStack(spacing: Theme.Spacing.xs) {
          RoundedRectangle(cornerRadius: spec.value, style: .continuous)
            .fill(Theme.Colors.surfaceElevated)
            .frame(width: 56, height: 56)
            .overlay(
              RoundedRectangle(cornerRadius: spec.value, style: .continuous)
                .strokeBorder(Theme.Colors.accent, lineWidth: 1)
            )
          Text(spec.name)
            .font(.crCaption)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
      }
    }
  }

  // MARK: Buttons

  private var buttonsSection: some View {
    VStack(spacing: Theme.Spacing.md) {
      Button("Play") {}
        .buttonStyle(.crPrimary)
      Button("Continue") {}
        .buttonStyle(.crPrimary)
      Button("Start Over") {}
        .buttonStyle(.crDanger)
      Button { } label: {
        HStack(spacing: Theme.Spacing.md) {
          Image(systemName: "play.fill")
            .font(.system(size: 28, weight: .bold))
          Text("Play")
        }
      }
      .buttonStyle(.crPrimaryCircular)
      HStack(spacing: Theme.Spacing.md) {
        Button { } label: {
          Image(systemName: "xmark")
            .font(.system(size: 18, weight: .bold))
        }
        .buttonStyle(.crIcon)
        Button { } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 18, weight: .bold))
        }
        .buttonStyle(.crIcon)
        Button { } label: {
          Image(systemName: "house.fill")
            .font(.system(size: 22, weight: .bold))
        }
        .buttonStyle(.crIcon(tint: Theme.Colors.accent))
        Button { } label: {
          Image(systemName: "trophy.fill")
            .font(.system(size: 22, weight: .bold))
        }
        .buttonStyle(.crIcon(tint: Theme.Colors.pro))
      }
    }
  }

  // MARK: Components

  private var componentsSection: some View {
    VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
      CRSectionHeader(title: "Pick a Mode", step: "Step 1/2", onBack: {})

      CRCard {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
          Text("Color ONLY")
            .font(.crHeadline)
            .foregroundStyle(Theme.Colors.textPrimary)
          Text("A color is called. Tap any square that's not that color.")
            .font(.crBody)
            .foregroundStyle(Theme.Colors.textSecondary)
        }
      }

      HStack {
        CRChip(title: "Recommended to start", tone: .accent)
        CRChip(title: "Pure", tone: .neutral)
      }

      CRHeartsPill(remaining: 4, total: 5)

      VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
        Text("TARGET: 250")
          .font(.crLabel)
          .foregroundStyle(Theme.Colors.accentSecondary)
        CRProgressBar(progress: 0.4)
      }

      HStack(spacing: Theme.Spacing.md) {
        CRStatBadge(label: "Hits", value: "+240", tone: .success)
        CRStatBadge(label: "Misses", value: "0", tone: .warning)
        CRStatBadge(label: "Streak", value: "+20", tone: .info)
      }
    }
  }
}

#Preview {
  DesignSystemPreview()
}

#endif
