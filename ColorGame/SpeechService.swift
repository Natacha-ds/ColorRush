//
//  SpeechService.swift
//  ColorRush
//
//  Created by Natacha Dehass on 26/09/2025.
//

import AVFoundation
import Foundation

final class SpeechService {
  // Pre-built players keyed by color. Reusing a primed AVAudioPlayer
  // skips the per-call decode + session-activation cost that surfaced
  // as audible leading silence on device.
  private var players: [String: AVAudioPlayer] = [:]

  init() {
    configureAudioSession()
    preloadPlayers()
  }

  private func configureAudioSession() {
    #if os(iOS)
    do {
      try AVAudioSession.sharedInstance().setCategory(
        .ambient,
        mode: .default,
        options: [.mixWithOthers]
      )
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to configure audio session: \(error.localizedDescription)")
    }
    #endif
  }

  private func preloadPlayers() {
    let mapping: [String: String] = [
      "red": "Red-voice",
      "blue": "Blue-voice",
      "green": "Green-voice",
      "yellow": "Yellow-voice",
    ]

    // Resolve via the user's first preferred localization explicitly. The
    // implicit Bundle.url(forResource:withExtension:) overload mixed up
    // resolution when CFBundleLocalizations and bundle-scanned lproj
    // entries co-existed; the explicit `localization:` parameter avoids it.
    let preferredLang = Bundle.main.preferredLocalizations.first
      ?? Bundle.main.developmentLocalization
      ?? "en"

    for (key, fileName) in mapping {
      let url = Bundle.main.url(
        forResource: fileName,
        withExtension: "mp3",
        subdirectory: nil,
        localization: preferredLang
      ) ?? Bundle.main.url(
        forResource: fileName,
        withExtension: "mp3",
        subdirectory: nil,
        localization: "en"
      )

      guard let url else {
        print("Audio file not found in bundle: \(fileName).mp3")
        continue
      }

      do {
        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        players[key] = player
      } catch {
        print("Error preparing audio player for \(fileName): \(error.localizedDescription)")
      }
    }
  }

  func speak(_ text: String) {
    let key = text.lowercased()
    guard let player = players[key] else {
      print("No audio player ready for color: \(text)")
      return
    }

    // Stop any voice currently playing, then start the requested one
    // from the beginning. All players stay primed across calls.
    for other in players.values where other.isPlaying {
      other.stop()
      other.currentTime = 0
    }
    player.currentTime = 0
    player.play()
  }
}
