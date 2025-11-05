//
//  AudioManager.swift
//  MediaMio
//
//  Manages audio playback for app sounds
//

import AVFoundation

@MainActor
class AudioManager {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Silently handle audio session setup failure
        }
    }

    func playStartupSound() {
        guard let soundURL = Bundle.main.url(forResource: "appintrosound", withExtension: "mp3") else {
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.volume = 0.5
            audioPlayer?.play()
        } catch {
            // Silently handle playback errors
        }
    }

    func stopStartupSound() {
        audioPlayer?.stop()
    }
}
