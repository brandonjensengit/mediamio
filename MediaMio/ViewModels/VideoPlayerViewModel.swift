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
    @Published var showSkipIntroButton: Bool = false

    // Debug stats
    @Published var currentBitrate: Double = 0.0  // bits per second
    @Published var observedBitrate: Double = 0.0  // observed bits per second from player
    @Published var availableSubtitles: [SubtitleTrack] = []
    @Published var selectedSubtitleIndex: Int? = nil  // nil = off

    let item: MediaItem
    private let authService: AuthenticationService
    private let settingsManager = SettingsManager()
    private var timeObserver: Any?
    private var progressReportTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var hasReportedStart: Bool = false
    private var isLoadingVideo: Bool = false

    // Intro/Credits markers
    private var introStart: Double?
    private var introEnd: Double?
    private var hasSkippedIntro: Bool = false

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

                // Check for resume position and seek if needed
                if let resumePosition = getResumePosition() {
                    print("⏩ Seeking to resume position: \(formatTime(resumePosition))")
                    let seekTime = CMTime(seconds: resumePosition, preferredTimescale: 600)

                    // Use completion handler to verify seek completed
                    await withCheckedContinuation { continuation in
                        avPlayer.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                            if finished {
                                print("✅ Seek completed successfully to \(self.formatTime(resumePosition))")
                            } else {
                                print("⚠️ Seek was interrupted or failed")
                            }
                            continuation.resume()
                        }
                    }
                } else {
                    print("▶️ Starting from beginning (no resume position)")
                }

                // Report playback start to Jellyfin
                await reportPlaybackStart()

                // Fetch intro markers for auto-skip
                await fetchIntroMarkers()

                // Configure subtitles based on settings
                configureSubtitles()
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

        // Apply settings from SettingsManager
        let videoCodec = VideoCodec(rawValue: settingsManager.videoCodec)?.jellyfinValue ?? "h264"
        let maxBitrate = settingsManager.maxBitrate

        // Build query items with settings
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "VideoCodec", value: videoCodec),
            URLQueryItem(name: "AudioCodec", value: "aac"),
            URLQueryItem(name: "MaxStreamingBitrate", value: "\(maxBitrate)"),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "MediaSourceId", value: item.id),
            URLQueryItem(name: "DeviceId", value: getDeviceId()),
            URLQueryItem(name: "api_key", value: accessToken)
        ]

        // Apply video quality setting (max height)
        if let videoQuality = VideoQuality(rawValue: settingsManager.videoQuality),
           let maxHeight = videoQuality.maxHeight {
            queryItems.append(URLQueryItem(name: "MaxHeight", value: "\(maxHeight)"))
            print("📊 Applying video quality: \(videoQuality.rawValue) (max height: \(maxHeight))")
        }

        // Apply audio quality setting
        if let audioQuality = AudioQuality(rawValue: settingsManager.audioQuality),
           audioQuality.bitrate > 0 {
            queryItems.append(URLQueryItem(name: "AudioBitrate", value: "\(audioQuality.bitrate)"))
            print("📊 Applying audio quality: \(audioQuality.rawValue) (\(audioQuality.bitrate) bps)")
        }

        components?.queryItems = queryItems

        let url = components?.url
        print("🔗 HLS Master Playlist URL: \(url?.absoluteString ?? "nil")")
        print("📊 Settings applied: Bitrate=\(maxBitrate/1_000_000)Mbps, Codec=\(videoCodec)")
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
        print("🔍 Checking resume position for: \(item.name)")
        print("   userData: \(item.userData != nil)")
        print("   playbackPositionTicks: \(item.userData?.playbackPositionTicks ?? 0)")
        print("   runTimeTicks: \(item.runTimeTicks ?? 0)")

        guard let userData = item.userData,
              let position = userData.playbackPositionTicks,
              let total = item.runTimeTicks else {
            print("   ❌ No resume data available")
            return nil
        }

        let progress = Double(position) / Double(total) * 100.0
        let seconds = Double(position) / 10_000_000.0

        print("   Progress: \(String(format: "%.1f", progress))%")
        print("   Resume position: \(formatTime(seconds))")

        // Only resume if between 1% and 95%
        if progress > 1.0 && progress < 95.0 {
            print("   ✅ Will resume from \(formatTime(seconds))")
            return seconds  // Convert ticks to seconds
        } else {
            print("   ⏭️ Progress outside resume range (1%-95%), starting from beginning")
            return nil
        }
    }

    // MARK: - Intro/Credits Detection

    private func fetchIntroMarkers() async {
        print("🎬 Fetching intro markers from Jellyfin")

        guard let url = URL(string: "\(baseURL)/Shows/\(item.id)/IntroTimestamps") else {
            print("❌ Failed to create intro markers URL")
            return
        }

        var request = URLRequest(url: url)
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 200 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let showIntros = json["ShowIntroTimestamps"] as? [String: Any],
                       let intro = showIntros.values.first as? [String: Any] {
                        if let start = intro["IntroStart"] as? Double,
                           let end = intro["IntroEnd"] as? Double {
                            introStart = start
                            introEnd = end
                            print("✅ Intro detected: \(formatTime(start)) - \(formatTime(end))")
                        }
                    }
                } else if httpResponse.statusCode == 404 {
                    print("ℹ️ No intro markers available for this item")
                } else {
                    print("⚠️ Intro markers request returned: \(httpResponse.statusCode)")
                }
            }
        } catch {
            print("⚠️ Failed to fetch intro markers: \(error)")
        }
    }

    func skipIntro() {
        guard let player = player, let end = introEnd else { return }
        print("⏭️ Skipping intro to: \(formatTime(end))")
        let seekTime = CMTime(seconds: end, preferredTimescale: 600)
        player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
        hasSkippedIntro = true
        showSkipIntroButton = false
    }

    private func checkIntroSkip(at currentTime: Double) {
        guard let start = introStart, let end = introEnd else { return }
        guard !hasSkippedIntro else { return }

        // Check if we're in the intro range
        let isInIntro = currentTime >= start && currentTime <= end

        if isInIntro {
            // Show skip button if enabled in settings
            if settingsManager.showSkipIntroButton {
                showSkipIntroButton = true
            }

            // Auto-skip if enabled in settings
            if settingsManager.autoSkipIntros {
                // Add a small delay countdown if configured
                let countdown = settingsManager.skipIntroCountdown
                if countdown > 0 {
                    // Check if we're at the start of intro (within 1 second)
                    if abs(currentTime - start) < 1.0 {
                        print("⏳ Auto-skipping intro in \(countdown) seconds...")
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(countdown)) { [weak self] in
                            guard let self = self, !self.hasSkippedIntro else { return }
                            self.skipIntro()
                        }
                    }
                } else {
                    // Skip immediately
                    skipIntro()
                }
            }
        } else if currentTime > end {
            // Past the intro, hide button
            showSkipIntroButton = false
        }
    }

    // MARK: - Subtitle Configuration

    private func configureSubtitles() {
        guard let player = player, let playerItem = player.currentItem else {
            return
        }

        // Get available subtitle tracks
        guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return
        }

        // Populate available subtitles
        availableSubtitles = group.options.enumerated().map { index, option in
            SubtitleTrack(
                index: index,
                displayName: option.displayName,
                languageCode: option.locale?.languageCode ?? "unknown",
                option: option
            )
        }

        let subtitleMode = SubtitleMode(rawValue: settingsManager.subtitleMode) ?? .off

        switch subtitleMode {
        case .off:
            // Disable all subtitle tracks
            playerItem.select(nil, in: group)
            selectedSubtitleIndex = nil

        case .on, .foreignOnly, .smart:
            // Enable subtitles based on default language setting
            let defaultLang = settingsManager.defaultSubtitleLanguage

            // Try to find matching language
            let matchingOption = group.options.enumerated().first { _, option in
                if let locale = option.locale {
                    return locale.languageCode == defaultLang
                }
                return false
            }

            if let (index, option) = matchingOption {
                playerItem.select(option, in: group)
                selectedSubtitleIndex = index
            } else if let firstOption = group.options.first {
                playerItem.select(firstOption, in: group)
                selectedSubtitleIndex = 0
            }
        }
    }

    func selectSubtitle(at index: Int?) {
        guard let player = player, let playerItem = player.currentItem else {
            return
        }

        guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            return
        }

        if let index = index, index >= 0 && index < group.options.count {
            // Enable subtitle at index
            let option = group.options[index]
            playerItem.select(option, in: group)
            selectedSubtitleIndex = index
        } else {
            // Disable subtitles
            playerItem.select(nil, in: group)
            selectedSubtitleIndex = nil
        }
    }

    var currentSubtitleName: String {
        if let index = selectedSubtitleIndex, index < availableSubtitles.count {
            return availableSubtitles[index].displayName
        }
        return "Off"
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

                // Check for intro skip
                self.checkIntroSkip(at: currentSeconds)

                // Update observed bitrate from player
                self.updateObservedBitrate()
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

                    // CRITICAL: Check for resume position before starting playback
                    Task { @MainActor in
                        guard let self = self, let player = self.player else { return }

                        // Check if we should resume from a saved position
                        if let resumePosition = self.getResumePosition() {
                            print("⏩ [Status Observer] Seeking to resume position: \(self.formatTime(resumePosition))")
                            let seekTime = CMTime(seconds: resumePosition, preferredTimescale: 600)

                            await withCheckedContinuation { continuation in
                                player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
                                    if finished {
                                        print("✅ [Status Observer] Seek completed successfully")
                                    } else {
                                        print("⚠️ [Status Observer] Seek was interrupted")
                                    }
                                    continuation.resume()
                                }
                            }
                        } else {
                            print("▶️ [Status Observer] Starting from beginning")
                        }

                        // Start playback after seeking (or immediately if no resume)
                        player.play()
                        print("▶️ AUTO-STARTED playback from .readyToPlay status")

                        // Report to Jellyfin if not already reported
                        await self.reportPlaybackStart()

                        // Fetch intro markers and configure subtitles
                        await self.fetchIntroMarkers()
                        self.configureSubtitles()
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

        // Calculate if video was mostly watched
        let progressPercent = (duration > 0) ? (currentTime / duration) * 100.0 : 0.0
        let wasCompleted = progressPercent >= 90.0

        print("📊 Final position: \(formatTime(currentTime)) / \(formatTime(duration)) (\(String(format: "%.1f", progressPercent))%)")

        // Report playback stopped with final position
        Task {
            await reportPlaybackStopped(completed: wasCompleted)

            // Mark as watched if >= 90% complete
            if wasCompleted {
                await markAsWatched()
            }
        }

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

    private func markAsWatched() async {
        print("✅ Marking item as watched (>= 90% complete)")

        guard let url = URL(string: "\(baseURL)/Users/\(userId)/PlayedItems/\(item.id)") else {
            print("❌ Failed to create mark as watched URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(accessToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Marked as watched: \(httpResponse.statusCode)")
            }
        } catch {
            print("⚠️ Failed to mark as watched: \(error)")
        }
    }

    // MARK: - Debug Stats

    private func updateObservedBitrate() {
        guard let playerItem = player?.currentItem else { return }

        // Get access log to read current bitrate
        if let accessLog = playerItem.accessLog(),
           let lastEvent = accessLog.events.last {
            observedBitrate = lastEvent.indicatedBitrate
        }
    }

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

// MARK: - Subtitle Track Model

struct SubtitleTrack: Identifiable {
    let index: Int
    let displayName: String
    let languageCode: String
    let option: AVMediaSelectionOption

    var id: Int { index }
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
        return String(format: "%.1f Mbps", Double(maxBitrate) / 1_000_000.0)
    }

    var observedBitrateMbps: String {
        if observedBitrate > 0 {
            return String(format: "%.2f Mbps", observedBitrate / 1_000_000.0)
        }
        return "N/A"
    }

    var bufferPercent: String {
        return String(format: "%.0f%%", bufferProgress)
    }
}
