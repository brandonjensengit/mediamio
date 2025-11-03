//
//  VideoPlayerViewModel.swift
//  MediaMio
//
//  Created by Claude Code
//  Phase 5: Video Player State Management
//

import Foundation
import AVKit
import Combine

@MainActor
class VideoPlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var progress: Double = 0.0  // 0-1
    @Published var bufferedProgress: Double = 0.0  // 0-1
    @Published var currentTime: Double = 0.0  // seconds
    @Published var duration: Double = 0.0  // seconds

    let item: MediaItem
    private let authService: AuthenticationService
    private var timeObserver: Any?
    private var progressReportTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var hasReportedStart: Bool = false
    private var isLoadingVideo: Bool = false

    var baseURL: String {
        authService.currentSession?.serverURL ?? ""
    }

    var accessToken: String {
        authService.currentSession?.accessToken ?? ""
    }

    var userId: String {
        authService.currentSession?.user.id ?? ""
    }

    init(item: MediaItem, authService: AuthenticationService) {
        self.item = item
        self.authService = authService
    }

    nonisolated deinit {
        print("🗑️ VideoPlayerViewModel deinit")

        // Note: Cannot access @MainActor properties from deinit
        // Cleanup happens automatically when the view model is deallocated
        // The Combine cancellables will be cleaned up automatically
    }

    // MARK: - Video Loading

    func loadVideoURL() async {
        // Prevent duplicate loading
        guard !isLoadingVideo else {
            print("⚠️ Video already loading, skipping duplicate request")
            return
        }

        isLoadingVideo = true
        isLoading = true
        errorMessage = nil

        do {
            // Construct streaming URL
            guard let streamURL = buildStreamingURL() else {
                errorMessage = "Failed to construct streaming URL"
                isLoading = false
                return
            }

            print("🎬 Loading video from: \(streamURL.absoluteString)")

            // Verify URL is accessible with proper headers
            var headRequest = URLRequest(url: streamURL)
            headRequest.httpMethod = "HEAD"
            headRequest.timeoutInterval = 5.0
            headRequest.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")

            print("🔍 Testing URL accessibility...")
            do {
                let (_, headResponse) = try await URLSession.shared.data(for: headRequest)
                if let httpResponse = headResponse as? HTTPURLResponse {
                    print("✅ URL accessible: HTTP \(httpResponse.statusCode)")
                    print("✅ Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "none")")

                    if httpResponse.statusCode != 200 && httpResponse.statusCode != 206 {
                        errorMessage = "Server returned HTTP \(httpResponse.statusCode)"
                        isLoading = false
                        isLoadingVideo = false
                        return
                    }
                }
            } catch {
                print("⚠️ HEAD request failed: \(error)")
                let nsError = error as NSError
                print("⚠️ Error domain: \(nsError.domain), code: \(nsError.code)")
                // Don't abort - some servers don't support HEAD
            }

            // Create AVPlayer with asset that includes auth headers
            let asset = AVURLAsset(url: streamURL, options: [
                "AVURLAssetHTTPHeaderFieldsKey": [
                    "X-Emby-Token": accessToken
                ]
            ])

            print("✅ Creating player item with authenticated asset...")
            let playerItem = AVPlayerItem(asset: asset)
            let avPlayer = AVPlayer(playerItem: playerItem)

            // Set audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)

            self.player = avPlayer

            // Setup observers
            setupTimeObserver()
            setupPlayerObservers(playerItem: playerItem)

            // Wait for player item to be ready
            print("⏳ Waiting for player item to be ready...")
            await waitForPlayerItemReady(playerItem: playerItem)

            // CRITICAL: Check if player item failed during wait
            if playerItem.status == .failed {
                print("❌ Player item failed after wait, aborting playback")
                if let error = playerItem.error {
                    let nsError = error as NSError
                    print("❌ Failure reason: \(error.localizedDescription)")
                    print("❌ Error code: \(nsError.code), domain: \(nsError.domain)")
                    errorMessage = "Playback failed: \(error.localizedDescription)"
                } else {
                    errorMessage = "Video playback failed with unknown error"
                }
                self.player = nil
                isLoading = false
                isLoadingVideo = false
                return
            }

            // For HLS streams, player item might still be loading
            if playerItem.status == .readyToPlay {
                print("✅ Player item confirmed ready, proceeding with playback")

                // Check for resume position
                if let resumePosition = getResumePosition() {
                    let seekTime = CMTime(seconds: resumePosition, preferredTimescale: 1)
                    await avPlayer.seek(to: seekTime)
                    print("⏩ Resuming from: \(formatTime(resumePosition))")
                }

                // Report playback start to Jellyfin
                await reportPlaybackStart()
            } else if playerItem.status == .unknown {
                print("⏳ HLS stream still loading (status: unknown)")
                print("⏳ Continuing - status observer will auto-start playback when ready")
                // Don't seek or report yet - wait for .readyToPlay status
                // The status observer will handle playback start automatically
            }
            // Note: .failed status was already handled above at line 134

            isLoading = false
            isLoadingVideo = false

        } catch {
            print("❌ Failed to load video: \(error)")
            errorMessage = "Failed to load video: \(error.localizedDescription)"
            isLoading = false
            isLoadingVideo = false
        }
    }

    private func buildStreamingURL() -> URL? {
        // Use Jellyfin's HLS master playlist for adaptive streaming with transcoding
        var components = URLComponents(string: baseURL)
        components?.path = "/Videos/\(item.id)/master.m3u8"

        // HLS streaming parameters
        components?.queryItems = [
            URLQueryItem(name: "VideoCodec", value: "h264"),
            URLQueryItem(name: "AudioCodec", value: "aac"),
            URLQueryItem(name: "MaxStreamingBitrate", value: "20000000"),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "MediaSourceId", value: item.id),
            URLQueryItem(name: "DeviceId", value: getDeviceId()),
            URLQueryItem(name: "api_key", value: accessToken)
        ]

        let url = components?.url
        print("🔗 HLS Master Playlist URL: \(url?.absoluteString ?? "nil")")
        return url
    }

    private func getDeviceId() -> String {
        // Use a consistent device ID for this session
        if let deviceId = UserDefaults.standard.string(forKey: "JellyfinDeviceId") {
            return deviceId
        }
        let newDeviceId = UUID().uuidString
        UserDefaults.standard.set(newDeviceId, forKey: "JellyfinDeviceId")
        return newDeviceId
    }

    private func waitForPlayerItemReady(playerItem: AVPlayerItem) async {
        print("🔍 Current player item status: \(playerItem.status.rawValue)")
        print("🔍 Player item error: \(String(describing: playerItem.error))")
        print("🔍 Player item tracks: \(playerItem.tracks.count)")

        // Check current status first
        if playerItem.status == .readyToPlay {
            print("✅ Player item already ready to play")
            return
        } else if playerItem.status == .failed {
            print("❌ Player item already failed")
            if let error = playerItem.error {
                print("❌ Error details: \(error)")
                print("❌ Error localized: \(error.localizedDescription)")
                errorMessage = "Failed to load video: \(error.localizedDescription)"
            }
            return
        }

        // Wait for status change with timeout
        let startTime = Date()
        for await status in playerItem.publisher(for: \.status).values {
            let elapsed = Date().timeIntervalSince(startTime)
            print("🔍 Player item status changed to: \(status.rawValue) after \(elapsed)s")

            switch status {
            case .readyToPlay:
                print("✅ Player item ready to play")
                print("🔍 Duration: \(playerItem.duration.seconds)s")
                print("🔍 Tracks: \(playerItem.tracks.count)")
                return
            case .failed:
                if let error = playerItem.error {
                    print("❌ Player item failed: \(error)")
                    print("❌ Error code: \((error as NSError).code)")
                    print("❌ Error domain: \((error as NSError).domain)")
                    errorMessage = "Failed to load video: \(error.localizedDescription)"
                }
                return
            case .unknown:
                print("⏳ Player item status unknown, waiting... (\(Int(elapsed))s)")
                // HLS transcoding can take 15-30 seconds to start
                if elapsed > 30.0 {
                    print("⚠️ Still loading after 30s, but continuing (HLS may still work)")
                    // Don't set error - let the status observer handle actual failures
                    return
                }
            @unknown default:
                break
            }
        }
    }

    private func getResumePosition() -> Double? {
        guard let userData = item.userData,
              let position = userData.playbackPositionTicks,
              let total = item.runTimeTicks else {
            return nil
        }

        let progress = Double(position) / Double(total) * 100.0

        // Only resume if between 1% and 95%
        if progress > 1.0 && progress < 95.0 {
            return Double(position) / 10_000_000.0  // Convert ticks to seconds
        }

        return nil
    }

    // MARK: - Player Observers

    private func setupTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }

            let currentSeconds = time.seconds
            let durationSeconds = player.currentItem?.duration.seconds ?? 0

            if durationSeconds.isFinite && durationSeconds > 0 {
                self.currentTime = currentSeconds
                self.duration = durationSeconds
                self.progress = currentSeconds / durationSeconds
            }
        }

        // Start progress reporting timer (every 10 seconds)
        progressReportTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.reportPlaybackProgress()
            }
        }
    }

    private func setupPlayerObservers(playerItem: AVPlayerItem) {
        // Observe player item status changes
        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                print("🔍 Player item status changed: \(status.rawValue)")
                switch status {
                case .readyToPlay:
                    print("✅ Player item is ready to play")
                    if let duration = self?.player?.currentItem?.duration.seconds {
                        print("✅ Duration: \(duration)s")
                    }
                    // CRITICAL: Start playback when ready
                    DispatchQueue.main.async {
                        self?.player?.play()
                        print("▶️ AUTO-STARTED playback from .readyToPlay status")

                        // Report to Jellyfin if not already reported
                        Task {
                            await self?.reportPlaybackStart()
                        }
                    }
                case .failed:
                    print("❌ Player item failed")
                    if let error = playerItem.error {
                        print("❌ Error: \(error.localizedDescription)")
                        print("❌ Error code: \((error as NSError).code)")
                        self?.errorMessage = error.localizedDescription
                    }
                case .unknown:
                    print("⏳ Player item status unknown")
                @unknown default:
                    print("⚠️ Unknown player item status")
                }
            }
            .store(in: &cancellables)

        // Observe playback status
        player?.publisher(for: \.timeControlStatus)
            .sink { [weak self] status in
                print("🔍 Time control status: \(status == .playing ? "playing" : status == .paused ? "paused" : "waiting")")
                self?.isPlaying = (status == .playing)
            }
            .store(in: &cancellables)

        // Observe player errors
        player?.publisher(for: \.error)
            .sink { [weak self] error in
                if let error = error {
                    print("❌ Player error: \(error.localizedDescription)")
                    print("❌ Player error code: \((error as NSError).code)")
                    self?.errorMessage = error.localizedDescription
                }
            }
            .store(in: &cancellables)

        // Observe buffering
        playerItem.publisher(for: \.loadedTimeRanges)
            .sink { [weak self] ranges in
                guard let self = self,
                      let timeRange = ranges.first?.timeRangeValue,
                      let duration = self.player?.currentItem?.duration.seconds,
                      duration.isFinite && duration > 0 else { return }

                let bufferedSeconds = CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration)
                self.bufferedProgress = bufferedSeconds / duration
            }
            .store(in: &cancellables)

        // Observe playback end
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.reportPlaybackStopped(completed: true)
                }
            }
            .store(in: &cancellables)

        // Observe failed to play to end time
        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
            .sink { [weak self] notification in
                print("❌ Failed to play to end time")
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    print("❌ Error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Playback Controls

    func startPlayback() {
        guard let player = player else {
            print("❌ Cannot start playback: player is nil")
            return
        }

        print("▶️ Starting playback...")
        print("🔍 Player rate before play: \(player.rate)")
        print("🔍 Player status: \(player.status.rawValue)")
        print("🔍 Player item: \(String(describing: player.currentItem))")
        print("🔍 Player item status: \(player.currentItem?.status.rawValue ?? -1)")

        player.play()

        // Check rate after play
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("🔍 Player rate after play: \(player.rate)")
            print("🔍 Player timeControlStatus: \(player.timeControlStatus.rawValue)")

            if player.rate == 0 {
                print("⚠️ Player rate is 0 - playback not starting!")
                if let error = player.currentItem?.error {
                    print("❌ Player item error: \(error)")
                }
            }
        }
    }

    func pausePlayback() {
        print("⏸️ Pausing playback...")
        player?.pause()
    }

    func togglePlayPause() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    func seekBackward() {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let seekTime = CMTimeSubtract(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: seekTime)
    }

    func seekForward() {
        guard let player = player else { return }
        let currentTime = player.currentTime()
        let seekTime = CMTimeAdd(currentTime, CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: seekTime)
    }

    func cleanup() {
        print("🧹 Cleaning up VideoPlayerViewModel")

        // Cancel all Combine subscriptions
        cancellables.removeAll()

        // Remove time observer
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }

        // Invalidate timers
        progressReportTimer?.invalidate()
        progressReportTimer = nil

        // Stop playback
        player?.pause()
        player = nil

        print("✅ Cleanup complete")
    }

    // MARK: - Formatting

    var currentTimeFormatted: String {
        formatTime(currentTime)
    }

    var remainingTimeFormatted: String {
        let remaining = duration - currentTime
        return "-" + formatTime(remaining)
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }

        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }

    // MARK: - Jellyfin Playback Reporting

    private func reportPlaybackStart() async {
        // Prevent duplicate start reports
        guard !hasReportedStart else {
            print("⚠️ Playback start already reported, skipping duplicate")
            return
        }

        hasReportedStart = true
        print("📊 Reporting playback start to Jellyfin")

        guard let url = URL(string: "\(baseURL)/Sessions/Playing") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")

        let body: [String: Any] = [
            "ItemId": item.id,
            "SessionId": UUID().uuidString,
            "PositionTicks": Int64(currentTime * 10_000_000),
            "IsPaused": false,
            "IsMuted": false,
            "PlayMethod": "DirectPlay"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Playback start reported: \(httpResponse.statusCode)")
            }
        } catch {
            // Check if it's a cancellation error (happens during view transitions)
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                print("ℹ️ Playback start report cancelled (view transition)")
                hasReportedStart = false  // Allow retry since it was cancelled
            } else {
                print("⚠️ Failed to report playback start: \(error)")
            }
        }
    }

    private func reportPlaybackProgress() async {
        guard isPlaying else { return }

        print("📊 Reporting playback progress: \(formatTime(currentTime))")

        guard let url = URL(string: "\(baseURL)/Sessions/Playing/Progress") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")

        let body: [String: Any] = [
            "ItemId": item.id,
            "PositionTicks": Int64(currentTime * 10_000_000),
            "IsPaused": !isPlaying,
            "IsMuted": false,
            "PlayMethod": "DirectPlay"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            _ = try await URLSession.shared.data(for: request)
        } catch {
            print("⚠️ Failed to report progress: \(error)")
        }
    }

    private func reportPlaybackStopped(completed: Bool) async {
        print("📊 Reporting playback stopped (completed: \(completed))")

        guard let url = URL(string: "\(baseURL)/Sessions/Playing/Stopped") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")

        let body: [String: Any] = [
            "ItemId": item.id,
            "PositionTicks": Int64(currentTime * 10_000_000),
            "PlayMethod": "DirectPlay"
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Playback stopped reported: \(httpResponse.statusCode)")
            }
        } catch {
            print("⚠️ Failed to report playback stopped: \(error)")
        }
    }
}
