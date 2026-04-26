import SwiftUI

struct ColorTile: View {
  let color: Color
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      RoundedRectangle(cornerRadius: 20)
        .fill(color)
        .frame(width: 120, height: 120)
        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 3)
    }
    .buttonStyle(PlainButtonStyle())
  }
}
