//
//  PlaybackFailoverController.swift
//  MediaMio
//
//  Phase A refactor: extracted from VideoPlayerViewModel (lines 1362–1437 of
//  the original — the "after 3 seconds, check if the stream failed and retry
//  in transcode mode" logic). Owns nothing else: the orchestrator supplies
//  a callback that performs the actual reload.
//

import AVFoundation
import Foundation

/// Watches a freshly-created `AVPlayerItem` for early failure and, if the
/// initial mode wasn't already Transcode, asks the orchestrator to retry
/// with a transcode URL. The retry callback is invoked at most once per
/// session — `hasFallbackAttempted` guards against retry loops.
///
/// Note on the 3-second timer (preserved from the original): the review
/// flagged this as too aggressive — network jitter can flip a stream to
/// `.failed` only briefly. A future refactor should observe `playable` /
/// buffer-fill instead. For Phase A we preserve behavior exactly.
@MainActor
final class PlaybackFailoverController {
    private var fallbackCheckTask: Task<Void, Never>?
    private var hasFallbackAttempted: Bool = false
    private(set) var currentMode: PlaybackMode?

    func setMode(_ mode: PlaybackMode) {
        currentMode = mode
    }

    /// Schedule a 3-second check on the given player item. If it has failed
    /// by then and we weren't already transcoding, invoke `onFallback` so
    /// the orchestrator can rebuild the player with a transcode URL.
    func arm(playerItem: AVPlayerItem, onFallback: @escaping () async -> Void) {
        fallbackCheckTask?.cancel()

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🛡️ AUTOMATIC FALLBACK ENABLED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🛡️ Current mode: \(currentMode?.rawValue ?? "unknown")")
        print("🛡️ Will check status after 3 seconds")

        fallbackCheckTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            guard let self = self, !Task.isCancelled else {
                print("🛡️ Fallback check cancelled")
                return
            }

            print("🛡️ FALLBACK CHECK (status: \(playerItem.status.rawValue), mode: \(self.currentMode?.rawValue ?? "unknown"))")

            guard playerItem.status == .failed else {
                if playerItem.status == .readyToPlay {
                    print("✅ Playback successful - no fallback needed")
                } else {
                    print("⏳ Playback still loading after 3 seconds")
                }
                return
            }

            if self.currentMode == .transcode {
                print("❌ Already in transcode mode, cannot fallback further")
                return
            }

            if self.hasFallbackAttempted {
                print("❌ Fallback already attempted, not retrying")
                return
            }

            print("🔄 Initiating automatic fallback to transcode mode...")
            self.hasFallbackAttempted = true
            await onFallback()
        }
    }

    func cancel() {
        fallbackCheckTask?.cancel()
        fallbackCheckTask = nil
    }
}
