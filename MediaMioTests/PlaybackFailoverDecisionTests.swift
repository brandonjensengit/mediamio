//
//  PlaybackFailoverDecisionTests.swift
//  MediaMioTests
//
//  Locks the pure decision function inside `PlaybackFailoverController`. The
//  controller's wiring (Combine subscriptions on AVPlayerItem) is hard to
//  unit-test without a real AV stack, so the decision logic was extracted
//  into `PlaybackFailoverController.decide(_:)` — a pure function over a
//  `Snapshot` struct. This file pins every reachable branch.
//
//  Pre-fix bug being guarded: a 3-second hardcoded sleep used to demote any
//  stream that wasn't `.readyToPlay` after 3 seconds. Slow handshakes on
//  fine connections false-positived constantly. The new logic only fires
//  the watchdog branch when the player is genuinely stuck.
//

import Testing
import AVFoundation
@testable import MediaMio

@MainActor
struct PlaybackFailoverDecisionTests {

    // MARK: - Helpers

    private func snapshot(
        status: AVPlayerItem.Status = .unknown,
        hasErrorNotification: Bool = false,
        bufferEmpty: Bool = true,
        likelyToKeepUp: Bool = false,
        watchdogElapsed: Bool = false,
        mode: PlaybackMode? = .directPlay,
        attempted: Bool = false
    ) -> PlaybackFailoverController.Snapshot {
        .init(
            status: status,
            hasErrorNotification: hasErrorNotification,
            isPlaybackBufferEmpty: bufferEmpty,
            isPlaybackLikelyToKeepUp: likelyToKeepUp,
            watchdogElapsed: watchdogElapsed,
            currentMode: mode,
            hasFallbackAttempted: attempted
        )
    }

    // MARK: - Standdown branches

    @Test("Once fallback has been attempted, never re-trigger")
    func standsDownAfterAttempt() {
        let s = snapshot(status: .failed, attempted: true)
        #expect(PlaybackFailoverController.decide(s) == .standDown)
    }

    @Test("Already in transcode mode — there is no lower fallback")
    func standsDownWhenAlreadyTranscoding() {
        let s = snapshot(status: .failed, mode: .transcode)
        #expect(PlaybackFailoverController.decide(s) == .standDown)
    }

    @Test("readyToPlay always stands down")
    func standsDownOnReadyToPlay() {
        let s = snapshot(status: .readyToPlay, mode: .directPlay)
        #expect(PlaybackFailoverController.decide(s) == .standDown)
    }

    // MARK: - Fallback branches

    @Test("status .failed triggers fallback immediately")
    func fallsBackOnFailedStatus() {
        let s = snapshot(status: .failed, mode: .directPlay)
        #expect(PlaybackFailoverController.decide(s) == .fallback)
    }

    @Test("Error notification triggers fallback even if status hasn't flipped")
    func fallsBackOnErrorNotification() {
        let s = snapshot(status: .unknown,
                         hasErrorNotification: true,
                         mode: .directStream)
        #expect(PlaybackFailoverController.decide(s) == .fallback)
    }

    @Test("Stuck stream (watchdog elapsed, buffer empty, not likely to keep up) falls back")
    func fallsBackWhenGenuinelyStuck() {
        let s = snapshot(status: .unknown,
                         bufferEmpty: true,
                         likelyToKeepUp: false,
                         watchdogElapsed: true)
        #expect(PlaybackFailoverController.decide(s) == .fallback)
    }

    // MARK: - The bug-fix cases (these were the old false-positives)

    @Test("Slow handshake — watchdog elapsed but player IS likely to keep up — must NOT fall back")
    func doesNotFalseFallbackOnSlowButHealthy() {
        let s = snapshot(status: .unknown,
                         bufferEmpty: false,
                         likelyToKeepUp: true,
                         watchdogElapsed: true)
        #expect(PlaybackFailoverController.decide(s) == .wait)
    }

    @Test("Watchdog elapsed but buffer is filling — must NOT fall back")
    func doesNotFalseFallbackWhenBufferFilling() {
        let s = snapshot(status: .unknown,
                         bufferEmpty: false,
                         likelyToKeepUp: false,
                         watchdogElapsed: true)
        #expect(PlaybackFailoverController.decide(s) == .wait)
    }

    @Test("Watchdog hasn't fired yet — no decision regardless of buffer state")
    func waitsBeforeWatchdogFires() {
        let s = snapshot(status: .unknown,
                         bufferEmpty: true,
                         likelyToKeepUp: false,
                         watchdogElapsed: false)
        #expect(PlaybackFailoverController.decide(s) == .wait)
    }

    // MARK: - Edge cases

    @Test("Failed status wins even after fallback attempted (still standDown — guard fires first)")
    func attemptedGuardWinsOverFailedStatus() {
        let s = snapshot(status: .failed, attempted: true)
        #expect(PlaybackFailoverController.decide(s) == .standDown)
    }

    @Test("Transcode + failed — still stand down (no further fallback)")
    func transcodeFailedStandsDown() {
        let s = snapshot(status: .failed, mode: .transcode)
        #expect(PlaybackFailoverController.decide(s) == .standDown)
    }

    @Test("Error notification while in transcode mode — stand down")
    func errorNotificationInTranscodeStandsDown() {
        let s = snapshot(hasErrorNotification: true, mode: .transcode)
        #expect(PlaybackFailoverController.decide(s) == .standDown)
    }

    @Test("Watchdog conditions met but mode is transcode — stand down")
    func stuckInTranscodeStandsDown() {
        let s = snapshot(status: .unknown,
                         bufferEmpty: true,
                         likelyToKeepUp: false,
                         watchdogElapsed: true,
                         mode: .transcode)
        #expect(PlaybackFailoverController.decide(s) == .standDown)
    }
}
