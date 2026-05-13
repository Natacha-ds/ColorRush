import SwiftUI

struct ColorTile: View {
  let color: Color
  let action: (CGPoint) -> Void

  /// Press-down state, driven by a DragGesture with zero minimum distance:
  /// onChanged fires on touch-down and keeps the state true while the finger
  /// is down; onEnded fires on touch-up. SpatialTapGesture stays alongside
  /// to capture the exact tap location for the particle burst.
  @State private var isPressed = false

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
      .scaleEffect(isPressed ? 0.88 : 1.0)
      .animation(.spring(response: 0.28, dampingFraction: 0.65), value: isPressed)
      .contentShape(shape)
      .gesture(
        SpatialTapGesture()
          .onEnded { event in
            action(event.location)
          }
      )
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in
            if !isPressed { isPressed = true }
          }
          .onEnded { _ in
            isPressed = false
          }
      )
  }
}
