//
//  AudioManager.swift
//  MediaMio
//
//  Owns the AVAudioSession lifecycle for the app: the splash uses `.ambient`
//  so it ducks under other audio; the video player uses `.playback` for
//  full-screen movie playback. Centralizing the category transitions here
//  means the player can re-enter playback mode on subsequent Plays without
//  paying the ~100–200ms `setCategory` cost every time.
//

import AVFoundation

@MainActor
class AudioManager {
    static let shared = AudioManager()
    private var audioPlayer: AVAudioPlayer?

    /// `.playback` category gets cached after the first transition — calling
    /// `enterPlaybackMode()` on subsequent Plays only flips `setActive(true)`,
    /// which is the cheap operation. The expensive `setCategory` runs once.
    private var isPlaybackCategoryActive = false

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

    /// Switch the shared audio session into video-playback mode. Called from
    /// `VideoPlayerViewModel.startPlayback` on every Play. Idempotent — the
    /// `setCategory` call is skipped on subsequent Plays in the same session.
    func enterPlaybackMode() {
        do {
            if !isPlaybackCategoryActive {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
                isPlaybackCategoryActive = true
            }
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            DebugLog.playback("⚠️ AVAudioSession enterPlaybackMode failed: \(error)")
        }
    }

    /// Deactivate the playback session on player teardown. Other apps get
    /// notified so they can resume their own audio if they were ducked.
    func exitPlaybackMode() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            DebugLog.playback("⚠️ AVAudioSession exitPlaybackMode failed: \(error)")
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
