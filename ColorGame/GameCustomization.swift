import Foundation

struct GameCustomization: Codable {
  var easySettings: EasyModeSettings
  var normalSettings: NormalModeSettings
  var hardSettings: HardModeSettings

  init() {
    easySettings = EasyModeSettings()
    normalSettings = NormalModeSettings()
    hardSettings = HardModeSettings()
  }
}

struct EasyModeSettings: Codable {
  var durationSeconds: Int
  var maxMistakes: Int

  init() {
    durationSeconds = 30 // Default 30 seconds
    maxMistakes = 2 // Default 2 mistakes
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
    roundTimeoutSeconds = 1.5 // Default 1.5 seconds
    maxMistakes = 2 // Default 2 mistakes
  }

  init(roundTimeoutSeconds: Double, maxMistakes: Int) {
    self.roundTimeoutSeconds = roundTimeoutSeconds
    self.maxMistakes = maxMistakes
  }
}

struct HardModeSettings: Codable {
  var confusionSpeedSeconds: Double
  var maxMistakes: Int

  init() {
    confusionSpeedSeconds = 1.8 // Default 1.8 seconds (Normal)
    maxMistakes = 2 // Default 2 mistakes
  }

  init(confusionSpeedSeconds: Double, maxMistakes: Int) {
    self.confusionSpeedSeconds = confusionSpeedSeconds
    self.maxMistakes = maxMistakes
  }
}

// Duration options for Easy mode
enum EasyDuration: Int, CaseIterable, Identifiable {
  case fifteen = 15
  case thirty = 30
  case sixty = 60

  var id: Int { rawValue }

  var displayName: String {
    switch self {
    case .fifteen: "15s"
    case .thirty: "30s"
    case .sixty: "60s"
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
    case .fast: "1.2s"
    case .normal: "1.5s"
    case .slow: "1.8s"
    }
  }

  var description: String {
    switch self {
    case .fast: "Fast (1.2s per round)"
    case .normal: "Normal (1.5s per round)"
    case .slow: "Slow (1.8s per round)"
    }
  }
}

// Max mistakes options for Easy mode
enum MaxMistakes: Int, CaseIterable, Identifiable {
  case zero = 0
  case one = 1
  case two = 2

  var id: Int { rawValue }

  var displayName: String {
    switch self {
    case .zero: "0"
    case .one: "1"
    case .two: "2"
    }
  }

  var description: String {
    switch self {
    case .zero: "Sudden Death (0 mistakes)"
    case .one: "1 mistake allowed"
    case .two: "2 mistakes allowed"
    }
  }
}

// Confusion speed options for Hard mode
enum HardConfusionSpeed: Double, CaseIterable, Identifiable {
  case slow = 2.0
  case normal = 1.8
  case fast = 1.5

  var id: Double { rawValue }

  var displayName: String {
    switch self {
    case .slow: "2.0s"
    case .normal: "1.8s"
    case .fast: "1.5s"
    }
  }

  var description: String {
    switch self {
    case .slow: "Slow (2.0s board refresh)"
    case .normal: "Normal (1.8s board refresh)"
    case .fast: "Fast (1.5s board refresh)"
    }
  }
}
