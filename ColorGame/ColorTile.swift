import SwiftUI

struct ColorTile: View {
  let color: Color
  let action: (CGPoint) -> Void

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
      .contentShape(shape)
      .gesture(
        SpatialTapGesture()
          .onEnded { event in
            action(event.location)
          }
      )
  }
}
