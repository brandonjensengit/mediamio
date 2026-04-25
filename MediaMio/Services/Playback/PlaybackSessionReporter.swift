//
//  PlaybackSessionReporter.swift
//  MediaMio
//
//  Phase A refactor: extracted from VideoPlayerViewModel (lines 1640–1762 of
//  the original). Wraps Jellyfin's playback-session HTTP API:
//  /Sessions/Playing, /Sessions/Playing/Progress, /Sessions/Playing/Stopped,
//  and /Users/{userId}/PlayedItems/{itemId}.
//
//  Constraint: no AVKit. The caller passes in the current playback position
//  (in seconds) and play method; this class only knows how to POST.
//

import Foundation

/// POSTs Jellyfin playback session events.
///
/// The previous monolithic implementation hardcoded `"PlayMethod": "DirectPlay"`
/// in every report regardless of the actual mode in use — Jellyfin's
/// server-side stats and Now Playing display were therefore always wrong for
/// Direct Stream / Remux / Transcode sessions. This class accepts the actual
/// `PlaybackMode` and reports it accurately.
@MainActor
final class PlaybackSessionReporter {
    private let baseURL: String
    private let accessToken: String
    private let item: MediaItem
    private let userId: String
    private let session: URLSession

    private var hasReportedStart: Bool = false

    init(
        baseURL: String,
        accessToken: String,
        item: MediaItem,
        userId: String,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.accessToken = accessToken
        self.item = item
        self.userId = userId
        self.session = session
    }

    func reportStart(positionSeconds: Double, mode: PlaybackMode) async {
        guard !hasReportedStart else {
            print("⚠️ Playback start already reported, skipping duplicate")
            return
        }
        hasReportedStart = true
        print("📊 Reporting playback start to Jellyfin (\(mode.rawValue))")

        guard let url = URL(string: "\(baseURL)/Sessions/Playing") else { return }

        let body: [String: Any] = [
            "ItemId": item.id,
            "SessionId": UUID().uuidString,
            "PositionTicks": Int64(positionSeconds * 10_000_000),
            "IsPaused": false,
            "IsMuted": false,
            "PlayMethod": jellyfinPlayMethod(for: mode)
        ]

        do {
            let (_, response) = try await postJSON(url: url, body: body)
            if let http = response as? HTTPURLResponse {
                print("✅ Playback start reported: \(http.statusCode)")
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("ℹ️ Playback start report cancelled (view transition)")
                hasReportedStart = false  // allow retry on a real new session
            } else {
                print("⚠️ Failed to report playback start: \(error)")
            }
        }
    }

    func reportProgress(positionSeconds: Double, isPlaying: Bool, mode: PlaybackMode) async {
        guard isPlaying else { return }

        guard let url = URL(string: "\(baseURL)/Sessions/Playing/Progress") else { return }

        let body: [String: Any] = [
            "ItemId": item.id,
            "PositionTicks": Int64(positionSeconds * 10_000_000),
            "IsPaused": !isPlaying,
            "IsMuted": false,
            "PlayMethod": jellyfinPlayMethod(for: mode)
        ]

        // Single retry on transient failure — the 10s ticker will catch up
        // anyway on the next interval if even the retry fails.
        await postJSONWithRetry(url: url, body: body, maxAttempts: 2, label: "progress")
    }

    func reportStopped(positionSeconds: Double, completed: Bool, mode: PlaybackMode) async {
        print("📊 Reporting playback stopped (completed: \(completed))")

        guard let url = URL(string: "\(baseURL)/Sessions/Playing/Stopped") else { return }

        let body: [String: Any] = [
            "ItemId": item.id,
            "PositionTicks": Int64(positionSeconds * 10_000_000),
            "PlayMethod": jellyfinPlayMethod(for: mode)
        ]

        // Last-write-wins: this is the call that determines whether resume
        // works at all. Three attempts with exponential backoff to survive
        // a transient blip (player-view tear-down racing the network stack).
        await postJSONWithRetry(url: url, body: body, maxAttempts: 3, label: "stopped")
    }

    func markAsWatched() async {
        print("✅ Marking item as watched (>= 90% complete)")

        guard let url = URL(string: "\(baseURL)/Users/\(userId)/PlayedItems/\(item.id)") else {
            print("❌ Failed to create mark-as-watched URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("✅ Marked as watched: \(http.statusCode)")
            }
        } catch {
            print("⚠️ Failed to mark as watched: \(error)")
        }
    }

    // MARK: - Private

    private func postJSON(url: URL, body: [String: Any]) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        return try await session.data(for: request)
    }

    /// POSTs the body and retries on transient network failures (timeouts,
    /// connection drops, cancellations from app suspension). 4xx responses
    /// are NOT retried — they signal a real protocol error, not a flake.
    /// Backoff: 200ms, 500ms, 1s.
    private func postJSONWithRetry(
        url: URL,
        body: [String: Any],
        maxAttempts: Int,
        label: String
    ) async {
        let backoffMs: [UInt64] = [200, 500, 1_000]
        for attempt in 1...maxAttempts {
            do {
                let (_, response) = try await postJSON(url: url, body: body)
                if let http = response as? HTTPURLResponse {
                    if (200...299).contains(http.statusCode) {
                        if attempt > 1 || label == "stopped" {
                            print("✅ Playback \(label) reported: \(http.statusCode) (attempt \(attempt))")
                        }
                        return
                    }
                    if (400...499).contains(http.statusCode) {
                        print("⚠️ Playback \(label) rejected by server: \(http.statusCode) — not retrying")
                        return
                    }
                    print("⚠️ Playback \(label) attempt \(attempt) returned \(http.statusCode)")
                }
            } catch {
                print("⚠️ Playback \(label) attempt \(attempt) failed: \(error.localizedDescription)")
            }
            if attempt < maxAttempts {
                let delay = backoffMs[min(attempt - 1, backoffMs.count - 1)]
                try? await Task.sleep(nanoseconds: delay * 1_000_000)
            }
        }
        print("❌ Playback \(label) gave up after \(maxAttempts) attempts")
    }

    /// Maps the internal `PlaybackMode` to the string Jellyfin expects in
    /// `PlayMethod`. Jellyfin only recognises `DirectPlay`, `DirectStream`,
    /// and `Transcode`; "Remux" is reported as `DirectStream` because that's
    /// the closest equivalent on the server side.
    private func jellyfinPlayMethod(for mode: PlaybackMode) -> String {
        switch mode {
        case .directPlay: return "DirectPlay"
        case .directStream: return "DirectStream"
        case .remux: return "DirectStream"
        case .transcode: return "Transcode"
        }
    }
}
