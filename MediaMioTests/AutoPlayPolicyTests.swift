//
//  AutoPlayPolicyTests.swift
//  MediaMioTests
//
//  Locks the auto-play state machine that prevents bitrate / audio-quality
//  reloads from silently unpausing the user. Pre-fix, the
//  `.readyToPlay` Combine sink in `VideoPlayerViewModel` unconditionally
//  called `player.play()`, so a paused user who changed their bitrate got
//  unpaused. The new behavior captures `wasPlaying` before the reload and
//  consumes it on the next `.readyToPlay`.
//

import Testing
@testable import MediaMio

struct AutoPlayPolicyTests {

    @Test("Default is to auto-play")
    func defaultsToTrue() {
        let policy = AutoPlayPolicy()
        #expect(policy.shouldAutoPlayNext == true)
    }

    @Test("Consume returns the current decision")
    func consumeReturnsCurrentValue() {
        var policy = AutoPlayPolicy()
        #expect(policy.consume() == true)
    }

    @Test("Consume resets to default (true) for the next session")
    func consumeResetsToDefault() {
        var policy = AutoPlayPolicy()
        policy.captureForReload(wasPlaying: false)
        _ = policy.consume()
        #expect(policy.shouldAutoPlayNext == true)
    }

    @Test("Reload while playing keeps auto-play enabled")
    func reloadWhilePlayingKeepsAutoPlay() {
        var policy = AutoPlayPolicy()
        policy.captureForReload(wasPlaying: true)
        #expect(policy.consume() == true)
    }

    @Test("Reload while paused suppresses auto-play (the bug fix)")
    func reloadWhilePausedSuppressesAutoPlay() {
        var policy = AutoPlayPolicy()
        policy.captureForReload(wasPlaying: false)
        #expect(policy.consume() == false)
    }

    @Test("Two consecutive reloads while paused both suppress")
    func twoConsecutivePausedReloadsBothSuppress() {
        var policy = AutoPlayPolicy()
        // First reload while paused
        policy.captureForReload(wasPlaying: false)
        #expect(policy.consume() == false)
        // Without recapture, the next session defaults back to play
        #expect(policy.consume() == true)
        // Second reload while paused must again suppress
        policy.captureForReload(wasPlaying: false)
        #expect(policy.consume() == false)
    }

    @Test("Recapture before consume overwrites the pending decision")
    func recaptureBeforeConsumeOverwrites() {
        var policy = AutoPlayPolicy()
        policy.captureForReload(wasPlaying: false)
        policy.captureForReload(wasPlaying: true)
        #expect(policy.consume() == true)
    }

    @Test("Initial play (no reload) auto-plays")
    func initialPlayWithoutReloadAutoPlays() {
        // Mirrors the "user just navigated to the player view" path —
        // no reload happens, so consume() should return the default true.
        var policy = AutoPlayPolicy()
        #expect(policy.consume() == true)
    }
}
