import SwiftUI

struct Tile {
    let backgroundColor: Color
    let textLabel: String
    
    init(backgroundColor: Color, textLabel: String) {
        self.backgroundColor = backgroundColor
        self.textLabel = textLabel
    }
    
    // Single truthy validator for Hard mode - used for both grid generation and tap evaluation
    func isValidHard(announcedColor: Color) -> Bool {
        let announcedColorName = colorName(for: announcedColor)
        return backgroundColor != announcedColor && textLabel.uppercased() != announcedColorName.uppercased()
    }
    
    // Helper function to get color name from Color
    private func colorName(for color: Color) -> String {
        switch color {
        case .red: return "red"
        case .blue: return "blue"
        case .green: return "green"
        case .yellow: return "yellow"
        default: return "unknown"
        }
    }
}

// Extension to make Tile identifiable for SwiftUI
extension Tile: Identifiable {
    var id: String {
        "\(backgroundColor.description)-\(textLabel)"
    }
}

// Extension to make Tile equatable for comparison
extension Tile: Equatable {
    static func == (lhs: Tile, rhs: Tile) -> Bool {
        return lhs.backgroundColor == rhs.backgroundColor && lhs.textLabel == rhs.textLabel
    }
}
