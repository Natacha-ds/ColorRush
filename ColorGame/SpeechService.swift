//
//  SpeechService.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import AVFoundation
import Foundation

class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    
    func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5 // Slightly slower for clarity
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
    }
}
