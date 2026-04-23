//
//  PlaybackLifecycleController.swift
//  MediaMio
//
//  Phase E (player correctness): owns app-lifecycle (background /
//  foreground) and AVAudioSession interruption (incoming calls,
//  Siri) handling for the active playback session.
//
//  The pre-existing behavior only paused on `willResignActive` and
//  never resumed on return — background → foreground left the
//  player stuck paused. Audio-session interruptions were not
//  handled at all, so any interruption killed playback silently.
//

import AVFoundation
import Combine
import Foundation
import UIKit

/// Pure state machine + notification bridge. Does not know about
/// `AVPlayer` directly — the orchestrator injects `isPlaying` /
/// `pause` / `resume` callbacks. That split keeps the controller
/// unit-testable: every branch of the state machine can be driven
/// from test code without touching `AVFoundation` or the system
/// shared audio session.
///
/// Contract:
///  - `willResignActive`: if `isPlaying()`, record the fact and pause. Already-paused → no-op.
///  - `didBecomeActive`: if the pre-background state was "playing", resume; clear the flag.
///  - audio interruption `.began`: record `isPlaying()` and pause. The OS has
///    already stopped audio, but calling `pause()` keeps the VM's `isPlaying`
///    state consistent without waiting on the AVPlayer's KVO to catch up.
///  - audio interruption `.ended` with `.shouldResume` + pre-interruption was playing:
///    re-activate the shared audio session (required, or `play()` silently no-ops) and resume.
///  - audio interruption `.ended` otherwise: clear the flag, do nothing.
@MainActor
final class PlaybackLifecycleController {
    typealias AudioSessionActivator = () throws -> Void

    private let isPlaying: () -> Bool
    private let pause: () -> Void
    private let resume: () -> Void
    private let activateAudioSession: AudioSessionActivator

    private(set) var wasPlayingBeforeInterruption: Bool = false
    private var cancellables: Set<AnyCancellable> = []

    init(
        isPlaying: @escaping () -> Bool,
        pause: @escaping () -> Void,
        resume: @escaping () -> Void,
        activateAudioSession: @escaping AudioSessionActivator = {
            try AVAudioSession.sharedInstance().setActive(true)
        }
    ) {
        self.isPlaying = isPlaying
        self.pause = pause
        self.resume = resume
        self.activateAudioSession = activateAudioSession
    }

    func start() {
        guard cancellables.isEmpty else { return }

        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.handleWillResignActive() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.handleDidBecomeActive() }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] note in
                Task { @MainActor [weak self] in self?.handleInterruptionNotification(note) }
            }
            .store(in: &cancellables)
    }

    func stop() {
        cancellables.removeAll()
        wasPlayingBeforeInterruption = false
    }

    // MARK: - Testable handlers

    func handleWillResignActive() {
        if isPlaying() {
            wasPlayingBeforeInterruption = true
            pause()
        }
    }

    func handleDidBecomeActive() {
        guard wasPlayingBeforeInterruption else { return }
        wasPlayingBeforeInterruption = false
        resume()
    }

    func handleInterruption(
        type: AVAudioSession.InterruptionType,
        options: AVAudioSession.InterruptionOptions
    ) {
        switch type {
        case .began:
            let wasPlaying = isPlaying()
            wasPlayingBeforeInterruption = wasPlaying
            if wasPlaying { pause() }
        case .ended:
            let shouldResume = options.contains(.shouldResume) && wasPlayingBeforeInterruption
            wasPlayingBeforeInterruption = false
            guard shouldResume else { return }
            do {
                try activateAudioSession()
            } catch {
                print("⚠️ Failed to re-activate audio session after interruption: \(error)")
                return
            }
            resume()
        @unknown default:
            break
        }
    }

    // MARK: - Notification parsing

    private func handleInterruptionNotification(_ note: Notification) {
        guard let info = note.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else {
            return
        }
        let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
        let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw)
        handleInterruption(type: type, options: options)
    }
}
