//
//  HapticsService.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

#if canImport(UIKit)
import UIKit
#endif

class HapticsService {
    static let shared = HapticsService()
    
    private init() {}
    
    func lightImpact() {
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
    
    func heavyImpact() {
        #if canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()
        #endif
    }
}
