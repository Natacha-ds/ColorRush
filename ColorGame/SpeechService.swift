//
//  SpeechService.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import AVFoundation
import Foundation

class SpeechService {
    private var audioPlayer: AVAudioPlayer?
    
    // Map color names to audio file names
    private func audioFileName(for colorName: String) -> String? {
        let lowercased = colorName.lowercased()
        switch lowercased {
        case "red":
            return "Red-voice"
        case "blue":
            return "Blue-voice"
        case "green":
            return "Green-voice"
        case "yellow":
            return "Yellow-voice"
        default:
            return nil
        }
    }
    
    func speak(_ text: String) {
        // Stop any ongoing audio playback
        audioPlayer?.stop()
        audioPlayer = nil
        
        // Get the audio file name for the color
        guard let audioFileName = audioFileName(for: text) else {
            print("No audio file found for color: \(text)")
            return
        }
        
        // Find the audio file in the bundle
        // Files should be added to Xcode project and included in the app bundle
        guard let url = Bundle.main.url(forResource: audioFileName, withExtension: "mp3") else {
            print("Audio file not found in bundle: \(audioFileName).mp3")
            print("Make sure the file is added to the Xcode project and included in the app target")
            return
        }
        
        // Create and play the audio
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("Error playing audio: \(error.localizedDescription)")
        }
    }
}
