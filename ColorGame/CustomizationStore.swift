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
    
    // Normal mode settings (placeholder for future)
    func updateNormalSettings(_ settings: NormalModeSettings) {
        customization.normalSettings = settings
        saveCustomization()
    }
    
    // Hard mode settings (placeholder for future)
    func updateHardSettings(_ settings: HardModeSettings) {
        customization.hardSettings = settings
        saveCustomization()
    }
}
