import SwiftUI

struct ColorTile: View {
  let color: Color
  let action: (CGPoint) -> Void

  /// Press-down state. Driven by a zero-duration LongPressGesture so the
  /// tile springs back automatically the instant the finger lifts, even if
  /// the user drags off-tile mid-press. SpatialTapGesture stays alongside
  /// to keep capturing the exact tap location for the particle burst.
  @GestureState private var isPressed = false

  var body: some View {
    let shape = RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
    return shape
      .fill(color)
      .frame(width: 150, height: 150)
      .overlay(
        shape
          .strokeBorder(
            LinearGradient(
              stops: [
                .init(color: Color.white.opacity(0.55), location: 0.0),
                .init(color: Color.white.opacity(0.18), location: 0.45),
                .init(color: Color.white.opacity(0.0), location: 0.7),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 2
          )
      )
      .scaleEffect(isPressed ? 0.92 : 1.0)
      .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPressed)
      .contentShape(shape)
      .gesture(
        SpatialTapGesture()
          .onEnded { event in
            action(event.location)
          }
      )
      .simultaneousGesture(
        LongPressGesture(minimumDuration: 0)
          .updating($isPressed) { _, state, _ in
            state = true
          }
      )
  }
}
