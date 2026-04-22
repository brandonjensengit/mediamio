//
//  VideoPlayerViewModel.swift
//  MediaMio
//
//  Phase A refactor: this used to be a 1,830-line god-object bundling six
//  concerns (URL building, subtitle selection, intro/credits, failover,
//  session reporting, AVPlayer lifecycle). Five of those six concerns now
//  live in `Services/Playback/`. This file is now just the orchestrator —
//  it owns the AVPlayer, sets up KVO/Combine observers on the player item,
//  and delegates everything else.
//

import AVKit
import Combine
import Foundation

@MainActor
final class VideoPlayerViewModel: ObservableObject {
    // MARK: - Player state (consumed by VideoPlayerView)

    @Published var player: AVPlayer?
    @Published var isPlaying: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var progress: Double = 0.0
    @Published var bufferedProgress: Double = 0.0
    @Published var currentTime: Double = 0.0
    @Published var duration: Double = 0.0

    /// Re-published from `IntroCreditsController` so the view can bind to a
    /// single observable object (the VM) and not have to learn about the
    /// internal service split.
    @Published var showSkipIntroButton: Bool = false

    /// Re-published from `SubtitleTrackManager` for the same reason.
    @Published var availableSubtitles: [SubtitleTrack] = []
    @Published var selectedSubtitleIndex: Int? = nil

    @Published var observedBitrate: Double = 0.0
    @Published var currentBitrate: Double = 0.0  // legacy: callers may set this from outside

    // MARK: - Inputs

    let item: MediaItem
    private let authService: AuthenticationService
    private let settingsManager = SettingsManager()

    var baseURL: String { authService.currentSession?.serverURL ?? "" }
    var accessToken: String { authService.currentSession?.accessToken ?? "" }
    var userId: String { authService.currentSession?.user.id ?? "" }

    // MARK: - Private state

    private var timeObserver: Any?
    private var progressReportTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var subtitleSubscriptions: Set<AnyCancellable> = []
    private var introSubscriptions: Set<AnyCancellable> = []
    private var isLoadingVideo: Bool = false

    // Services. Lazily initialized once we have the playback URL.
    private var sessionReporter: PlaybackSessionReporter?
    private var introController: IntroCreditsController?
    private var subtitleManager: SubtitleTrackManager?
    private let failoverController = PlaybackFailoverController()

    init(item: MediaItem, authService: AuthenticationService) {
        self.item = item
        self.authService = authService
    }

    nonisolated deinit {
        print("🗑️ VideoPlayerViewModel deinit")
    }

    // MARK: - Loading

    func loadVideoURL() async {
        print("🎬 loadVideoURL() — item: \(item.name)")

        guard !isLoadingVideo else {
            print("⚠️ Video already loading, skipping duplicate request")
            return
        }
        isLoadingVideo = true
        isLoading = true
        errorMessage = nil

        let urlBuilder = PlaybackStreamURLBuilder(
            item: item,
            baseURL: baseURL,
            accessToken: accessToken,
            deviceId: getDeviceId(),
            settingsManager: settingsManager
        )

        guard let result = urlBuilder.build() else {
            errorMessage = "Failed to construct streaming URL"
            isLoading = false
            isLoadingVideo = false
            return
        }

        failoverController.setMode(result.mode)
        await startPlayback(url: result.url, mode: result.mode)
    }

    /// Shared startup path used by both initial load and transcode failover.
    private func startPlayback(url: URL, mode: PlaybackMode) async {
        print("🎬 LOADING VIDEO — \(item.name) (\(mode.rawValue))")
        print("🔗 URL: \(url.absoluteString)")

        // HEAD request to surface obvious errors (404/auth) before AVPlayer
        // wraps them in opaque AVFoundationErrorDomain failures. Some
        // servers reject HEAD; that's tolerated.
        var headRequest = URLRequest(url: url)
        headRequest.httpMethod = "HEAD"
        headRequest.timeoutInterval = 5.0
        headRequest.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (_, headResponse) = try await URLSession.shared.data(for: headRequest)
            if let http = headResponse as? HTTPURLResponse {
                print("✅ HEAD returned: \(http.statusCode)")
                if http.statusCode != 200 && http.statusCode != 206 {
                    errorMessage = "Server returned HTTP \(http.statusCode)"
                    isLoading = false
                    isLoadingVideo = false
                    return
                }
            }
        } catch {
            print("⚠️ HEAD request failed (continuing anyway): \(error)")
        }

        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": ["X-Emby-Token": accessToken]
        ])
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 10.0

        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.appliesMediaSelectionCriteriaAutomatically = true

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("⚠️ AVAudioSession configuration failed: \(error)")
        }

        self.player = avPlayer

        // Build / rebind services for this playback session.
        sessionReporter = PlaybackSessionReporter(
            baseURL: baseURL,
            accessToken: accessToken,
            item: item,
            userId: userId
        )
        bindIntroController()
        bindSubtitleManager()

        setupTimeObserver()
        setupPlayerObservers(playerItem: playerItem)

        // Arm failover (no-op if mode is already transcode — the controller
        // checks internally).
        failoverController.arm(playerItem: playerItem) { [weak self] in
            await self?.retryWithTranscode()
        }

        await waitForPlayerItemReady(playerItem: playerItem)

        if playerItem.status == .failed {
            print("❌ Player item failed during initial load")
            errorMessage = playerItem.error.map { "Playback failed: \($0.localizedDescription)" }
                ?? "Video playback failed with unknown error"
            self.player = nil
            isLoading = false
            isLoadingVideo = false
            return
        }

        if playerItem.status == .readyToPlay {
            if let resumePosition = getResumePosition() {
                print("⏩ Seeking to resume position: \(formatTime(resumePosition))")
                let seekTime = CMTime(seconds: resumePosition, preferredTimescale: 600)
                await withCheckedContinuation { continuation in
                    avPlayer.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                        continuation.resume()
                    }
                }
            }

            await sessionReporter?.reportStart(positionSeconds: currentTime, mode: mode)
            await introController?.fetchMarkers()
            subtitleManager?.configure(player: avPlayer)
        }

        isLoading = false
        isLoadingVideo = false
    }

    private func retryWithTranscode() async {
        print("🔄 Retrying playback with transcode mode...")
        cleanupAVResources()

        // Build a transcode-only URL. Reuse PlaybackStreamURLBuilder by
        // forcing the streaming-mode setting up the call chain isn't
        // possible without mutating user settings, so we build the URL
        // directly here using the same parameters the builder would use in
        // the .transcode arm. Cheapest correct path: re-run the builder —
        // it will pick transcode again because we've already fallen through
        // direct play / direct stream / remux.
        let builder = PlaybackStreamURLBuilder(
            item: item,
            baseURL: baseURL,
            accessToken: accessToken,
            deviceId: getDeviceId(),
            settingsManager: settingsManager
        )
        guard let result = builder.build() else {
            errorMessage = "Failed to retry playback"
            return
        }
        failoverController.setMode(.transcode)
        await startPlayback(url: result.url, mode: .transcode)
    }

    // MARK: - Service bindings

    private func bindIntroController() {
        let controller = IntroCreditsController(
            baseURL: baseURL,
            accessToken: accessToken,
            itemId: item.id,
            settingsManager: settingsManager
        )
        introController = controller
        introSubscriptions.removeAll()
        controller.$showSkipIntroButton
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.showSkipIntroButton = $0 }
            .store(in: &introSubscriptions)
    }

    private func bindSubtitleManager() {
        let manager = SubtitleTrackManager(item: item, settingsManager: settingsManager)
        subtitleManager = manager
        subtitleSubscriptions.removeAll()
        manager.$availableTracks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.availableSubtitles = $0 }
            .store(in: &subtitleSubscriptions)
        manager.$selectedIndex
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.selectedSubtitleIndex = $0 }
            .store(in: &subtitleSubscriptions)
    }

    // MARK: - View-facing actions

    func skipIntro() {
        introController?.skip(player: player)
    }

    func selectSubtitle(at index: Int?) {
        subtitleManager?.select(at: index, player: player)
    }

    func startPlayback() {
        player?.play()
    }

    func pausePlayback() {
        player?.pause()
    }

    func togglePlayPause() {
        if isPlaying { pausePlayback() } else { startPlayback() }
    }

    func seekBackward() {
        guard let player = player else { return }
        let seekTime = CMTimeSubtract(player.currentTime(), CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: seekTime)
    }

    func seekForward() {
        guard let player = player else { return }
        let seekTime = CMTimeAdd(player.currentTime(), CMTime(seconds: 10, preferredTimescale: 1))
        player.seek(to: seekTime)
    }

    func cleanup() {
        print("🧹 Cleaning up VideoPlayerViewModel")

        let progressPercent = (duration > 0) ? (currentTime / duration) * 100.0 : 0.0
        let wasCompleted = progressPercent >= 90.0
        print("📊 Final position: \(formatTime(currentTime)) / \(formatTime(duration)) (\(String(format: "%.1f", progressPercent))%)")

        let mode = failoverController.currentMode ?? .directPlay
        let position = currentTime
        let reporter = sessionReporter

        Task {
            await reporter?.reportStopped(positionSeconds: position, completed: wasCompleted, mode: mode)
            if wasCompleted {
                await reporter?.markAsWatched()
            }
        }

        failoverController.cancel()
        cleanupAVResources()
    }

    private func cleanupAVResources() {
        cancellables.removeAll()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        progressReportTimer?.invalidate()
        progressReportTimer = nil
        player?.pause()
        player = nil
    }

    // MARK: - Observers

    private func setupTimeObserver() {
        guard let player = player else { return }

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            // Runs on the main queue (see `queue: .main` above), so we can
            // safely assume main-actor isolation without hopping through a
            // Task — at 0.5s cadence that would enqueue ~120 tasks/minute.
            MainActor.assumeIsolated {
                guard let self = self else { return }
                let currentSeconds = time.seconds
                let durationSeconds = player.currentItem?.duration.seconds ?? 0
                guard durationSeconds.isFinite, durationSeconds > 0 else { return }

                self.currentTime = currentSeconds
                self.duration = durationSeconds
                self.progress = currentSeconds / durationSeconds

                self.introController?.tick(currentTime: currentSeconds, player: player)
                self.updateObservedBitrate()
            }
        }

        progressReportTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let mode = self.failoverController.currentMode ?? .directPlay
                await self.sessionReporter?.reportProgress(
                    positionSeconds: self.currentTime,
                    isPlaying: self.isPlaying,
                    mode: mode
                )
            }
        }
    }

    private func setupPlayerObservers(playerItem: AVPlayerItem) {
        cancellables.removeAll()

        playerItem.publisher(for: \.status)
            .sink { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .readyToPlay:
                    print("✅ Player item is ready to play")
                    Task { @MainActor in
                        guard let player = self.player else { return }
                        if let resumePosition = self.getResumePosition() {
                            print("⏩ [Status Observer] Seeking to resume: \(self.formatTime(resumePosition))")
                            let seekTime = CMTime(seconds: resumePosition, preferredTimescale: 600)
                            await withCheckedContinuation { continuation in
                                player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                                    continuation.resume()
                                }
                            }
                        }
                        player.play()
                        let mode = self.failoverController.currentMode ?? .directPlay
                        await self.sessionReporter?.reportStart(positionSeconds: self.currentTime, mode: mode)
                        await self.introController?.fetchMarkers()
                        self.subtitleManager?.configure(player: player)
                    }
                case .failed:
                    if let error = playerItem.error {
                        print("❌ Player item failed: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                    }
                case .unknown:
                    print("⏳ Player item status unknown")
                @unknown default:
                    break
                }
            }
            .store(in: &cancellables)

        player?.publisher(for: \.timeControlStatus)
            .sink { [weak self] status in
                self?.isPlaying = (status == .playing)
            }
            .store(in: &cancellables)

        player?.publisher(for: \.error)
            .sink { [weak self] error in
                if let error = error {
                    print("❌ Player error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }
            .store(in: &cancellables)

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

        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                Task { @MainActor in
                    guard let self = self else { return }
                    let mode = self.failoverController.currentMode ?? .directPlay
                    await self.sessionReporter?.reportStopped(
                        positionSeconds: self.currentTime,
                        completed: true,
                        mode: mode
                    )
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .AVPlayerItemFailedToPlayToEndTime, object: playerItem)
            .sink { [weak self] notification in
                if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                    print("❌ Failed to play to end time: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }
            .store(in: &cancellables)
    }

    private func waitForPlayerItemReady(playerItem: AVPlayerItem) async {
        if playerItem.status == .readyToPlay { return }
        if playerItem.status == .failed {
            if let error = playerItem.error {
                errorMessage = "Failed to load video: \(error.localizedDescription)"
            }
            return
        }

        let startTime = Date()
        for await status in playerItem.publisher(for: \.status).values {
            let elapsed = Date().timeIntervalSince(startTime)
            switch status {
            case .readyToPlay:
                return
            case .failed:
                if let error = playerItem.error {
                    errorMessage = "Failed to load video: \(error.localizedDescription)"
                }
                return
            case .unknown:
                if elapsed > 30.0 {
                    print("⚠️ Still loading after 30s, but continuing (HLS may still work)")
                    return
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - Helpers

    private func getResumePosition() -> Double? {
        guard let userData = item.userData,
              let position = userData.playbackPositionTicks,
              let total = item.runTimeTicks else {
            return nil
        }
        let progress = Double(position) / Double(total) * 100.0
        let seconds = Double(position) / 10_000_000.0
        return (progress > 1.0 && progress < 95.0) ? seconds : nil
    }

    private func getDeviceId() -> String {
        if let deviceId = UserDefaults.standard.string(forKey: "JellyfinDeviceId") {
            return deviceId
        }
        let newDeviceId = UUID().uuidString
        UserDefaults.standard.set(newDeviceId, forKey: "JellyfinDeviceId")
        return newDeviceId
    }

    private func updateObservedBitrate() {
        if let event = player?.currentItem?.accessLog()?.events.last {
            observedBitrate = event.indicatedBitrate
        }
    }

    // MARK: - Formatting (used by view)

    var currentTimeFormatted: String { formatTime(currentTime) }
    var remainingTimeFormatted: String {
        "-" + formatTime(duration - currentTime)
    }
    var currentSubtitleName: String {
        subtitleManager?.currentName ?? "Off"
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        let secs = Int(seconds) % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, secs)
            : String(format: "%d:%02d", minutes, secs)
    }

    // MARK: - Debug

    var debugStats: DebugStats {
        let videoQuality = VideoQuality(rawValue: settingsManager.videoQuality) ?? .auto
        let audioQuality = AudioQuality(rawValue: settingsManager.audioQuality) ?? .high
        let videoCodec = VideoCodec(rawValue: settingsManager.videoCodec) ?? .h264
        let subtitleMode = SubtitleMode(rawValue: settingsManager.subtitleMode) ?? .off

        return DebugStats(
            videoQuality: videoQuality.rawValue,
            maxBitrate: settingsManager.maxBitrate,
            observedBitrate: observedBitrate,
            videoCodec: videoCodec.rawValue,
            audioQuality: audioQuality.rawValue,
            subtitleMode: subtitleMode.rawValue,
            bufferProgress: bufferedProgress * 100.0
        )
    }
}

// MARK: - Debug Stats Model

struct DebugStats {
    let videoQuality: String
    let maxBitrate: Int
    let observedBitrate: Double
    let videoCodec: String
    let audioQuality: String
    let subtitleMode: String
    let bufferProgress: Double

    var maxBitrateMbps: String {
        String(format: "%.1f Mbps", Double(maxBitrate) / 1_000_000.0)
    }

    var observedBitrateMbps: String {
        observedBitrate > 0
            ? String(format: "%.2f Mbps", observedBitrate / 1_000_000.0)
            : "N/A"
    }

    var bufferPercent: String {
        String(format: "%.0f%%", bufferProgress)
    }
}
