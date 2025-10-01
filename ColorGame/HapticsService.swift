//
//  HapticsService.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import UIKit

class HapticsService {
    static let shared = HapticsService()
    
    private init() {}
    
    func lightImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    func heavyImpact() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
    }
}
