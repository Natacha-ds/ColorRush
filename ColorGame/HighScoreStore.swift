//
//  HighScoreStore.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import Foundation
import Combine

class HighScoreStore: ObservableObject {
    static let shared = HighScoreStore()
    
    private let userDefaults = UserDefaults.standard
    private let easyKey = "best.easy"
    private let normalKey = "best.normal"
    private let hardKey = "best.hard"
    
    @Published var bestEasy: Int = 0
    @Published var bestNormal: Int = 0
    @Published var bestHard: Int = 0
    
    private init() {
        loadScores()
    }
    
    private func loadScores() {
        bestEasy = userDefaults.integer(forKey: easyKey)
        bestNormal = userDefaults.integer(forKey: normalKey)
        bestHard = userDefaults.integer(forKey: hardKey)
    }
    
    func getBestScore(for difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy:
            return bestEasy
        case .normal:
            return bestNormal
        case .hard:
            return bestHard
        }
    }
    
    func updateBestScore(for difficulty: Difficulty, score: Int) -> Bool {
        let currentBest = getBestScore(for: difficulty)
        
        if score > currentBest {
            switch difficulty {
            case .easy:
                bestEasy = score
                userDefaults.set(score, forKey: easyKey)
            case .normal:
                bestNormal = score
                userDefaults.set(score, forKey: normalKey)
            case .hard:
                bestHard = score
                userDefaults.set(score, forKey: hardKey)
            }
            
            userDefaults.synchronize()
            return true // New best score
        }
        
        return false // No new best
    }
    
    func resetAllScores() {
        bestEasy = 0
        bestNormal = 0
        bestHard = 0
        
        userDefaults.removeObject(forKey: easyKey)
        userDefaults.removeObject(forKey: normalKey)
        userDefaults.removeObject(forKey: hardKey)
        userDefaults.synchronize()
    }
}
