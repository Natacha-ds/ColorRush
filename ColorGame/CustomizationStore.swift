import Foundation
import Combine

class CustomizationStore: ObservableObject {
    static let shared = CustomizationStore()
    
    private let userDefaults = UserDefaults.standard
    private let customizationKey = "game.customization"
    
    @Published var customization: GameCustomization
    
    private init() {
        self.customization = GameCustomization()
        self.customization = loadCustomization()
    }
    
    private func loadCustomization() -> GameCustomization {
        guard let data = userDefaults.data(forKey: customizationKey),
              let customization = try? JSONDecoder().decode(GameCustomization.self, from: data) else {
            return GameCustomization() // Return default settings
        }
        return customization
    }
    
    private func saveCustomization() {
        if let data = try? JSONEncoder().encode(customization) {
            userDefaults.set(data, forKey: customizationKey)
        }
    }
    
    // Easy mode settings
    func updateEasyDuration(_ duration: Int) {
        customization.easySettings.durationSeconds = duration
        saveCustomization()
    }
    
    func updateEasyMaxMistakes(_ maxMistakes: Int) {
        customization.easySettings.maxMistakes = maxMistakes
        saveCustomization()
    }
    
    func updateEasySettings(duration: Int, maxMistakes: Int) {
        customization.easySettings.durationSeconds = duration
        customization.easySettings.maxMistakes = maxMistakes
        saveCustomization()
    }
    
    func getEasyDuration() -> Int {
        return customization.easySettings.durationSeconds
    }
    
    func getEasyMaxMistakes() -> Int {
        let result = customization.easySettings.maxMistakes
        return result
    }
    
    // Normal mode settings
    func updateNormalRoundTimeout(_ timeout: Double) {
        customization.normalSettings.roundTimeoutSeconds = timeout
        saveCustomization()
    }
    
    func updateNormalMaxMistakes(_ maxMistakes: Int) {
        customization.normalSettings.maxMistakes = maxMistakes
        saveCustomization()
    }
    
    func updateNormalSettings(roundTimeout: Double, maxMistakes: Int) {
        customization.normalSettings.roundTimeoutSeconds = roundTimeout
        customization.normalSettings.maxMistakes = maxMistakes
        saveCustomization()
    }
    
    func getNormalRoundTimeout() -> Double {
        return customization.normalSettings.roundTimeoutSeconds
    }
    
    func getNormalMaxMistakes() -> Int {
        return customization.normalSettings.maxMistakes
    }
    
    func updateNormalSettings(_ settings: NormalModeSettings) {
        customization.normalSettings = settings
        saveCustomization()
    }
    
    // Hard mode settings
    func updateHardConfusionSpeed(_ confusionSpeed: Double) {
        customization.hardSettings.confusionSpeedSeconds = confusionSpeed
        saveCustomization()
    }
    
    func updateHardMaxMistakes(_ maxMistakes: Int) {
        customization.hardSettings.maxMistakes = maxMistakes
        saveCustomization()
    }
    
    func updateHardSettings(confusionSpeed: Double, maxMistakes: Int) {
        customization.hardSettings.confusionSpeedSeconds = confusionSpeed
        customization.hardSettings.maxMistakes = maxMistakes
        saveCustomization()
    }
    
    func getHardConfusionSpeed() -> Double {
        return customization.hardSettings.confusionSpeedSeconds
    }
    
    func getHardMaxMistakes() -> Int {
        return customization.hardSettings.maxMistakes
    }
    
    func updateHardSettings(_ settings: HardModeSettings) {
        customization.hardSettings = settings
        saveCustomization()
    }
}
