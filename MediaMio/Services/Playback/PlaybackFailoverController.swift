//
//  PlaybackFailoverController.swift
//  MediaMio
//
//  Owns the "did the initial DirectPlay/DirectStream/Remux attempt fail —
//  should we retry in Transcode mode?" decision. Originally this was a
//  3-second `Task.sleep` after which the controller asked "are we failed
//  yet?" The audit flagged that as a lying signal: under network jitter
//  AVPlayer can sit at `.unknown` for a few seconds even when playback is
//  about to succeed, so we'd false-positive and demote a perfectly good
//  Direct Play stream to Transcode (worse quality, more server CPU, slower
//  start). Conversely a fast 404 / codec mismatch would still wait the full
//  3 seconds before failing over.
//
//  The current design observes the AVPlayer's actual signals:
//
//    1. `playerItem.status == .failed`        → fallback immediately
//    2. `failedToPlayToEndTimeNotification`   → fallback immediately
//    3. `playerItem.status == .readyToPlay`   AND a video track is present
//                                              → cancel; we're fine
//    4. `playerItem.status == .readyToPlay`   AND no video track 3s later
//                                              → fallback (silent video
//       decode failure — e.g. HEVC packaged in MPEG-TS HLS, which AVPlayer
//       accepts as `.readyToPlay` but cannot actually render. Audio plays,
//       black screen. Caught by `tracks.assetTrack.mediaType` having no
//       `.video` entry.)
//    5. Watchdog (15s) ONLY fires if status is still `.unknown` AND
//       buffer is empty AND not likely to keep up — the genuinely-stuck
//       case the old timer was actually trying to catch.
//
//  Constraint: this controller only handles **initial-load** failover. Once
//  playback has reached `.readyToPlay` AND a video track is confirmed,
//  mid-playback errors are the orchestrator's problem (and a separate UX —
//  you can't silently restart a viewing session under the user).
//

import AVFoundation
import Combine
import Foundation

@MainActor
final class PlaybackFailoverController {
    /// Pure decision function — given a snapshot of the player state, should
    /// we trigger the transcode fallback now? Extracted from the AV-aware
    /// wiring below so it can be unit-tested without an AVPlayerItem.
    struct Snapshot {
        let status: AVPlayerItem.Status
        let hasErrorNotification: Bool
        let isPlaybackBufferEmpty: Bool
        let isPlaybackLikelyToKeepUp: Bool
        let watchdogElapsed: Bool
        let currentMode: PlaybackMode?
        let hasFallbackAttempted: Bool
        /// True iff `playerItem.tracks` contains an enabled track with
        /// `assetTrack.mediaType == .video`. Used to detect the silent
        /// HEVC-in-MPEG-TS HLS failure where status reaches `.readyToPlay`
        /// but the video plane never receives frames.
        let hasVideoTrack: Bool
        /// Set by `schedulePostReadyCheck`. Distinct from `watchdogElapsed`
        /// (which is the long initial-load watchdog) so the decision
        /// function can tell "we're checking too early, keep waiting" from
        /// "we waited and still no video, pull the plug."
        let postReadyWatchdogElapsed: Bool
    }

    enum Decision: Equatable {
        /// Trigger transcode fallback now.
        case fallback
        /// Stand down — playback succeeded or fallback isn't applicable.
        case standDown
        /// Keep watching; the player hasn't decided yet.
        case wait
    }

    /// How long to wait before declaring a stalled-but-not-failed item
    /// genuinely hung. Conservative on purpose: this is the "AVPlayer never
    /// emits .failed but is also never going to play" case.
    static let watchdogSeconds: TimeInterval = 15

    /// How long to wait after `.readyToPlay` for a video track to appear
    /// before declaring this a silent-decode failure. AVPlayer normally
    /// populates `playerItem.tracks` synchronously with the readyToPlay
    /// flip; 3 seconds is grace for HLS variant selection on slow networks.
    static let postReadyWatchdogSeconds: TimeInterval = 3

    private var fallbackCheckTask: Task<Void, Never>?
    private var postReadyCheckTask: Task<Void, Never>?
    private var statusSubscription: AnyCancellable?
    private var errorSubscription: AnyCancellable?
    private var hasFallbackAttempted: Bool = false
    private(set) var currentMode: PlaybackMode?

    func setMode(_ mode: PlaybackMode) {
        currentMode = mode
    }

    /// Wire failure observation onto the given player item. Calls
    /// `onFallback` at most once per session (guarded by
    /// `hasFallbackAttempted`).
    func arm(playerItem: AVPlayerItem, onFallback: @escaping () async -> Void) {
        cancel()

        print("🛡️ Failover armed (mode: \(currentMode?.rawValue ?? "unknown"))")

        // Status flips cover the fast path: .failed fires within milliseconds
        // for 404 / codec errors / malformed manifests. On `.readyToPlay`,
        // we DON'T immediately cancel — we evaluate (which checks for a
        // video track) and, if tracks haven't populated yet, schedule the
        // post-ready check.
        statusSubscription = playerItem.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak playerItem] status in
                guard let self = self, let item = playerItem else { return }
                self.evaluate(playerItem: item,
                              hasErrorNotification: false,
                              watchdogElapsed: false,
                              postReadyWatchdogElapsed: false,
                              onFallback: onFallback)
                if status == .readyToPlay {
                    self.schedulePostReadyCheck(playerItem: item, onFallback: onFallback)
                }
            }

        // Some failure paths surface as a notification before / instead of a
        // status flip — particularly when the playlist is reachable but a
        // segment within it isn't.
        errorSubscription = NotificationCenter.default
            .publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak playerItem] _ in
                guard let self = self, let item = playerItem else { return }
                self.evaluate(playerItem: item,
                              hasErrorNotification: true,
                              watchdogElapsed: false,
                              postReadyWatchdogElapsed: false,
                              onFallback: onFallback)
            }

        // Slow-path watchdog. Catches the rare "stuck at .unknown forever"
        // case where neither status nor the error notification ever fires.
        fallbackCheckTask = Task { @MainActor [weak self, weak playerItem] in
            try? await Task.sleep(nanoseconds: UInt64(Self.watchdogSeconds * 1_000_000_000))
            guard let self = self,
                  let item = playerItem,
                  !Task.isCancelled else { return }
            self.evaluate(playerItem: item,
                          hasErrorNotification: false,
                          watchdogElapsed: true,
                          postReadyWatchdogElapsed: false,
                          onFallback: onFallback)
        }
    }

    /// Scheduled when status flips to `.readyToPlay` but tracks haven't yet
    /// confirmed a video stream. If video shows up before this fires, the
    /// next `evaluate()` cycle will hit standDown and cancel us. If 3
    /// seconds pass with no video track, the silent-decode-failure fallback
    /// kicks in.
    private func schedulePostReadyCheck(playerItem: AVPlayerItem,
                                        onFallback: @escaping () async -> Void) {
        postReadyCheckTask?.cancel()
        postReadyCheckTask = Task { @MainActor [weak self, weak playerItem] in
            try? await Task.sleep(nanoseconds: UInt64(Self.postReadyWatchdogSeconds * 1_000_000_000))
            guard let self = self,
                  let item = playerItem,
                  !Task.isCancelled else { return }
            self.evaluate(playerItem: item,
                          hasErrorNotification: false,
                          watchdogElapsed: false,
                          postReadyWatchdogElapsed: true,
                          onFallback: onFallback)
        }
    }

    func cancel() {
        fallbackCheckTask?.cancel()
        fallbackCheckTask = nil
        postReadyCheckTask?.cancel()
        postReadyCheckTask = nil
        statusSubscription = nil
        errorSubscription = nil
    }

    // MARK: - Decision

    static func decide(_ snapshot: Snapshot) -> Decision {
        if snapshot.hasFallbackAttempted { return .standDown }
        if snapshot.currentMode == .transcode { return .standDown }

        if snapshot.status == .failed { return .fallback }
        if snapshot.hasErrorNotification { return .fallback }

        if snapshot.status == .readyToPlay {
            // The healthy case: we have a real video track, we're done.
            if snapshot.hasVideoTrack { return .standDown }
            // The silent-decode-failure case: status said ready, audio is
            // probably playing, but no video track ever materialised.
            if snapshot.postReadyWatchdogElapsed { return .fallback }
            // Tracks haven't populated yet; the post-ready check is in
            // flight. Don't decide yet.
            return .wait
        }

        // Genuinely stuck: timer elapsed, buffer empty, player isn't
        // expecting to keep up. (`isPlaybackLikelyToKeepUp` is AVFoundation's
        // own "we're going to stall" signal — pairing it with empty buffer
        // and an elapsed watchdog removes the false-positive on a slow but
        // healthy connection.)
        if snapshot.watchdogElapsed
            && snapshot.status == .unknown
            && snapshot.isPlaybackBufferEmpty
            && !snapshot.isPlaybackLikelyToKeepUp {
            return .fallback
        }

        return .wait
    }

    // MARK: - Private

    private func evaluate(playerItem: AVPlayerItem,
                          hasErrorNotification: Bool,
                          watchdogElapsed: Bool,
                          postReadyWatchdogElapsed: Bool,
                          onFallback: @escaping () async -> Void) {
        let hasVideoTrack = playerItem.tracks.contains {
            $0.assetTrack?.mediaType == .video
        }

        let snapshot = Snapshot(
            status: playerItem.status,
            hasErrorNotification: hasErrorNotification,
            isPlaybackBufferEmpty: playerItem.isPlaybackBufferEmpty,
            isPlaybackLikelyToKeepUp: playerItem.isPlaybackLikelyToKeepUp,
            watchdogElapsed: watchdogElapsed,
            currentMode: currentMode,
            hasFallbackAttempted: hasFallbackAttempted,
            hasVideoTrack: hasVideoTrack,
            postReadyWatchdogElapsed: postReadyWatchdogElapsed
        )

        switch Self.decide(snapshot) {
        case .fallback:
            print("🔄 Failover triggered (status: \(playerItem.status.rawValue), errorNotif: \(hasErrorNotification), watchdog: \(watchdogElapsed), postReadyWatchdog: \(postReadyWatchdogElapsed), hasVideoTrack: \(hasVideoTrack))")
            hasFallbackAttempted = true
            // Cancel observers up-front so a late-arriving signal doesn't
            // call onFallback again before the guard above takes effect.
            statusSubscription = nil
            errorSubscription = nil
            fallbackCheckTask?.cancel()
            fallbackCheckTask = nil
            postReadyCheckTask?.cancel()
            postReadyCheckTask = nil
            Task { @MainActor in
                await onFallback()
            }
        case .standDown:
            // Healthy `.readyToPlay` with a real video track is the
            // definitive "we're done watching" state. Tear everything
            // down so a late status flip or notification can't reopen
            // the failover path.
            if snapshot.status == .readyToPlay && snapshot.hasVideoTrack {
                cancel()
            }
        case .wait:
            break
        }
    }
}
