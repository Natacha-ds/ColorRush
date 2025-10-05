import Foundation

struct GameCustomization: Codable {
    var easySettings: EasyModeSettings
    var normalSettings: NormalModeSettings
    var hardSettings: HardModeSettings
    
    init() {
        self.easySettings = EasyModeSettings()
        self.normalSettings = NormalModeSettings()
        self.hardSettings = HardModeSettings()
    }
}

struct EasyModeSettings: Codable {
    var durationSeconds: Int
    var maxMistakes: Int
    
    init() {
        self.durationSeconds = 30 // Default 30 seconds
        self.maxMistakes = 3 // Default 3 mistakes
    }
    
    init(durationSeconds: Int, maxMistakes: Int) {
        self.durationSeconds = durationSeconds
        self.maxMistakes = maxMistakes
    }
}

struct NormalModeSettings: Codable {
    // Placeholder for future Normal mode customizations
    init() {}
}

struct HardModeSettings: Codable {
    // Placeholder for future Hard mode customizations
    init() {}
}

// Duration options for Easy mode
enum EasyDuration: Int, CaseIterable, Identifiable {
    case fifteen = 15
    case thirty = 30
    case sixty = 60
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .fifteen: return "15s"
        case .thirty: return "30s"
        case .sixty: return "60s"
        }
    }
}

// Max mistakes options for Easy mode
enum MaxMistakes: Int, CaseIterable, Identifiable {
    case zero = 0
    case one = 1
    case two = 2
    case three = 3
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        }
    }
    
    var description: String {
        switch self {
        case .zero: return "Sudden Death (0 mistakes)"
        case .one: return "1 mistake allowed"
        case .two: return "2 mistakes allowed"
        case .three: return "3 mistakes allowed"
        }
    }
}
