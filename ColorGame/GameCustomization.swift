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
    var roundTimeoutSeconds: Double
    var maxMistakes: Int
    
    init() {
        self.roundTimeoutSeconds = 1.5 // Default 1.5 seconds
        self.maxMistakes = 3 // Default 3 mistakes
    }
    
    init(roundTimeoutSeconds: Double, maxMistakes: Int) {
        self.roundTimeoutSeconds = roundTimeoutSeconds
        self.maxMistakes = maxMistakes
    }
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

// Round timeout options for Normal mode
enum NormalRoundTimeout: Double, CaseIterable, Identifiable {
    case fast = 1.2
    case normal = 1.5
    case slow = 1.8
    
    var id: Double { rawValue }
    
    var displayName: String {
        switch self {
        case .fast: return "1.2s"
        case .normal: return "1.5s"
        case .slow: return "1.8s"
        }
    }
    
    var description: String {
        switch self {
        case .fast: return "Fast (1.2s per round)"
        case .normal: return "Normal (1.5s per round)"
        case .slow: return "Slow (1.8s per round)"
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
