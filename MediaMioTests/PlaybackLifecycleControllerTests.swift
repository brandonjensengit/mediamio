//
//  PlaybackLifecycleControllerTests.swift
//  MediaMioTests
//
//  Phase E: locks the lifecycle state machine so app-lifecycle and
//  audio-interruption semantics can't drift out from under us
//  unnoticed. The pre-fix behavior only paused on `willResignActive`
//  and silently broke playback on any interruption.
//

import Testing
import AVFoundation
@testable import MediaMio

@MainActor
struct PlaybackLifecycleControllerTests {

    // MARK: - Test harness

    /// Records calls made to the injected callbacks so assertions
    /// can see the sequence of events without touching AVPlayer.
    @MainActor
    final class Spy {
        var isPlaying: Bool = false
        var pauseCalls: Int = 0
        var resumeCalls: Int = 0
        var activateCalls: Int = 0
        var activateShouldThrow: Bool = false

        struct ActivationError: Error {}

        func makeController() -> PlaybackLifecycleController {
            PlaybackLifecycleController(
                isPlaying: { [unowned self] in self.isPlaying },
                pause: { [unowned self] in
                    self.pauseCalls += 1
                    self.isPlaying = false
                },
                resume: { [unowned self] in
                    self.resumeCalls += 1
                    self.isPlaying = true
                },
                activateAudioSession: { [unowned self] in
                    self.activateCalls += 1
                    if self.activateShouldThrow { throw ActivationError() }
                }
            )
        }
    }

    // MARK: - App lifecycle

    @Test func willResignActiveWhilePlaying_pausesAndRemembers() {
        let spy = Spy()
        let c = spy.makeController()
        spy.isPlaying = true

        c.handleWillResignActive()

        #expect(spy.pauseCalls == 1)
        #expect(spy.isPlaying == false)
        #expect(c.wasPlayingBeforeInterruption == true)
    }

    @Test func willResignActiveWhilePaused_doesNothing() {
        let spy = Spy()
        let c = spy.makeController()
        spy.isPlaying = false

        c.handleWillResignActive()

        #expect(spy.pauseCalls == 0)
        #expect(c.wasPlayingBeforeInterruption == false)
    }

    @Test func didBecomeActive_afterBackgroundedWhilePlaying_resumes() {
        let spy = Spy()
        let c = spy.makeController()
        spy.isPlaying = true
        c.handleWillResignActive()

        c.handleDidBecomeActive()

        #expect(spy.resumeCalls == 1)
        #expect(spy.isPlaying == true)
        #expect(c.wasPlayingBeforeInterruption == false)
    }

    @Test func didBecomeActive_afterBackgroundedWhilePaused_doesNotResume() {
        let spy = Spy()
        let c = spy.makeController()
        spy.isPlaying = false
        c.handleWillResignActive()

        c.handleDidBecomeActive()

        #expect(spy.resumeCalls == 0)
        #expect(spy.isPlaying == false)
    }

    // MARK: - Audio session interruption

    @Test func interruptionBeganWhilePlaying_pausesAndRemembers() {
        let spy = Spy()
        let c = spy.makeController()
        spy.isPlaying = true

        c.handleInterruption(type: .began, options: [])

        #expect(spy.pauseCalls == 1)
        #expect(spy.isPlaying == false)
        #expect(c.wasPlayingBeforeInterruption == true)
    }

    @Test func interruptionBeganWhilePaused_doesNotCallPause() {
        let spy = Spy()
        let c = spy.makeController()
        spy.isPlaying = false

        c.handleInterruption(type: .began, options: [])

        #expect(spy.pauseCalls == 0)
        #expect(c.wasPlayingBeforeInterruption == false)
    }

    @Test func interruptionEnded_withShouldResumeAfterPlaying_reactivatesAndResumes() {
        let spy = Spy()
        let c = spy.makeController()
        spy.isPlaying = true
        c.handleInterruption(type: .began, options: [])

        c.handleInterruption(type: .ended, options: [.shouldResume])

        #expect(spy.activateCalls == 1)
        #expect(spy.resumeCalls == 1)
        #expect(spy.isPlaying == true)
        #expect(c.wasPlayingBeforeInterruption == false)
    }

    @Test func interruptionEnded_withShouldResumeAfterPaused_doesNotResume() {
        let spy = Spy()
        let c = spy.makeController()
        spy.isPlaying = false
        c.handleInterruption(type: .began, options: [])

        c.handleInterruption(type: .ended, options: [.shouldResume])

        #expect(spy.activateCalls == 0)
        #expect(spy.resumeCalls == 0)
        #expect(c.wasPlayingBeforeInterruption == false)
    }

    @Test func interruptionEnded_withoutShouldResume_doesNotResume() {
        let spy = Spy()
        let c = spy.makeController()
        spy.isPlaying = true
        c.handleInterruption(type: .began, options: [])

        c.handleInterruption(type: .ended, options: [])

        #expect(spy.activateCalls == 0)
        #expect(spy.resumeCalls == 0)
        #expect(c.wasPlayingBeforeInterruption == false)
    }

    @Test func interruptionEnded_audioSessionActivationFails_doesNotResume() {
        let spy = Spy()
        spy.activateShouldThrow = true
        let c = spy.makeController()
        spy.isPlaying = true
        c.handleInterruption(type: .began, options: [])

        c.handleInterruption(type: .ended, options: [.shouldResume])

        #expect(spy.activateCalls == 1)
        #expect(spy.resumeCalls == 0)
        #expect(c.wasPlayingBeforeInterruption == false)
    }

    // MARK: - Lifecycle idempotency

    @Test func startIsIdempotent() {
        let spy = Spy()
        let c = spy.makeController()
        c.start()
        c.start()  // no crash, no duplicate subscriptions
        c.stop()
    }

    @Test func stopClearsPreInterruptionFlag() {
        let spy = Spy()
        let c = spy.makeController()
        spy.isPlaying = true
        c.handleWillResignActive()
        #expect(c.wasPlayingBeforeInterruption == true)

        c.stop()

        #expect(c.wasPlayingBeforeInterruption == false)
    }
}
