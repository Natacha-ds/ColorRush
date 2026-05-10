import SwiftUI

/// Plays the chosen click sound the moment the button transitions to the
/// pressed state. Driven off `ButtonStyle.Configuration.isPressed`, so any
/// ButtonStyle can opt in by chaining `.clickSound(_:isPressed:)` on its
/// returned view.
extension View {
  func clickSound(_ click: SoundService.Click, isPressed: Bool) -> some View {
    onChange(of: isPressed) { _, newValue in
      guard newValue else { return }
      SoundService.shared.play(click)
    }
  }
}
