//
//  AutoPlayPolicy.swift
//  MediaMio
//
//  Tracks whether the next time the player reaches `.readyToPlay` it
//  should auto-start playback. Default is yes — that's the normal "user
//  navigated to the video player" path. The reload path (bitrate / audio
//  quality change mid-playback) captures the pre-reload play/pause state
//  so a paused user isn't silently unpaused by a setting change.
//
//  Constraint: this struct knows nothing about AVPlayer. The orchestrator
//  calls `consume()` once it has a ready player and either calls `play()`
//  or doesn't, based on the result. Keeping it AV-free is what makes the
//  three-line state machine unit-testable without an AV stack.
//

import Foundation

struct AutoPlayPolicy: Equatable {
    private(set) var shouldAutoPlayNext: Bool = true

    /// Capture the user's current play/pause state before a stream reload
    /// so the next `.readyToPlay` transition restores it. Pass `false`
    /// when the user was paused — they'll stay paused after the reload.
    mutating func captureForReload(wasPlaying: Bool) {
        shouldAutoPlayNext = wasPlaying
    }

    /// Read the current decision and reset to the default (`true`) for the
    /// next session. The orchestrator should call this exactly once per
    /// `.readyToPlay` transition.
    mutating func consume() -> Bool {
        let decision = shouldAutoPlayNext
        shouldAutoPlayNext = true
        return decision
    }
}
