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
import UIKit

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
    @Published var showSkipCreditsButton: Bool = false

    /// Re-published from `SubtitleTrackManager` for the same reason.
    @Published var availableSubtitles: [SubtitleTrack] = []
    @Published var selectedSubtitleIndex: Int? = nil

    @Published var observedBitrate: Double = 0.0
    @Published var currentBitrate: Double = 0.0  // legacy: callers may set this from outside

    /// Mirrors `AVPlayer.defaultRate` so SwiftUI invalidates whenever the
    /// playback speed changes. The transport-bar speedometer menu's checkmark
    /// is rebuilt by `updateUIViewController`, which only fires on
    /// representable-prop changes — without this, mutating `defaultRate`
    /// from the menu's UIAction closure left the ✓ stuck on the previous
    /// rate until something else invalidated the view (QA-11).
    @Published private(set) var playbackRate: Float = 1.0

    // MARK: - Inputs

    /// The item being played. Starts as whatever the caller passed in
    /// (often a sparse `MediaItem` from `/Items/Resume` or `/Items/Latest`
    /// without `MediaSources`), and gets replaced by the full version
    /// returned from `getItemDetails()` in `refetchFullItemIfNeeded()`.
    /// `@Published` so the Playback Info panel re-renders after the fetch.
    @Published private(set) var item: MediaItem
    private let authService: AuthenticationService
    private let apiClient: JellyfinAPIClient
    private let settingsManager = SettingsManager()

    var baseURL: String { authService.currentSession?.serverURL ?? "" }
    var accessToken: String { authService.currentSession?.accessToken ?? "" }
    var userId: String { authService.currentSession?.user.id ?? "" }

    /// The playback mode that actually won the codec-decision fight for the
    /// active stream. Read by the "Playback Info" panel. Falls back to
    /// `.directPlay` only during the narrow window before `startPlayback`
    /// has told the failover controller which mode won.
    var currentPlaybackMode: PlaybackMode {
        failoverController.currentMode ?? .directPlay
    }

    /// Human label for the currently-selected subtitle track, or nil when
    /// subtitles are off. Matches `SubtitleTrack.displayName` so the info
    /// panel reads the same label the subtitle picker shows.
    var currentSubtitleDisplay: String? {
        guard let index = selectedSubtitleIndex,
              let track = availableSubtitles.first(where: { $0.index == index }) else {
            return nil
        }
        return track.displayName
    }

    // MARK: - Private state

    private var timeObserver: Any?
    private var progressReportTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    private var subtitleSubscriptions: Set<AnyCancellable> = []
    private var introSubscriptions: Set<AnyCancellable> = []
    private var defaultRateObservation: NSKeyValueObservation?
    private var isLoadingVideo: Bool = false

    // Services. Lazily initialized once we have the playback URL.
    private var sessionReporter: PlaybackSessionReporter?
    private var introController: IntroCreditsController?
    private var subtitleManager: SubtitleTrackManager?
    private var nowPlaying: NowPlayingPublisher?
    private let failoverController = PlaybackFailoverController()
    private var lifecycleController: PlaybackLifecycleController?

    init(
        item: MediaItem,
        authService: AuthenticationService,
        apiClient: JellyfinAPIClient,
        initialStartPositionTicks: Int64? = nil
    ) {
        self.item = item
        self.authService = authService
        self.apiClient = apiClient
        // Chapter jumps seed the resume-position via the same pending-seek
        // slot already used for bitrate reloads. `getResumePosition()` drains
        // this first, so it takes precedence over any server-provided resume
        // point — which is the expected behavior: the user explicitly asked
        // to start at this chapter.
        // nil  → auto-resume from userData.playbackPositionTicks
        // 0    → explicit "play from the beginning" (bypass userData)
        // N>0  → explicit seek target (chapter jump, resume-from-detail, etc.)
        if let ticks = initialStartPositionTicks {
            self.pendingSeekOnReload = Double(ticks) / 10_000_000.0
        }
        observeStreamingSettingsChanges()
    }

    /// The bitrate and audio-quality pickers live in UIKit custom-info view
    /// controllers (`CustomInfoViewControllers.swift`) and post
    /// notifications on change. Observe them here and reload the current
    /// stream so the new setting takes effect immediately instead of only
    /// on next play (the review called the pre-fix behavior a "lying UI").
    private func observeStreamingSettingsChanges() {
        let names: [Notification.Name] = [
            Notification.Name("ReloadVideoWithNewBitrate"),
            Notification.Name("ReloadVideoWithNewAudioQuality")
        ]
        for name in names {
            NotificationCenter.default.publisher(for: name)
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        await self?.reloadWithCurrentSettings()
                    }
                }
                .store(in: &cancellables)
        }
    }

    /// Tear down the active AVPlayer session and rebuild from
    /// `PlaybackStreamURLBuilder` — used when the user changes bitrate or
    /// audio quality mid-playback. Preserves `currentTime` as the resume
    /// position so the new stream picks up where the old one left off.
    func reloadWithCurrentSettings() async {
        DebugLog.playback("🔄 Reloading stream with updated settings (position: \(formatTime(currentTime)), wasPlaying: \(isPlaying))")
        let resumeFromCurrent = currentTime
        let wasPlaying = isPlaying
        cleanupAVResources()
        isLoadingVideo = false
        // `getResumePosition()` reads userData; override by nudging the item's
        // position via a local variable instead — but since we can't mutate
        // `self.item` (let), stash the seek target and apply it after load.
        pendingSeekOnReload = resumeFromCurrent
        // Preserve pause state across the reload — without this, a user who
        // paused before changing bitrate would silently get unpaused.
        autoPlayPolicy.captureForReload(wasPlaying: wasPlaying)
        await loadVideoURL()
    }

    /// Seconds to seek to once the next `startPlayback` settles. Used by
    /// mid-playback stream reloads (bitrate/audio quality change).
    private var pendingSeekOnReload: Double?

    /// Decides whether the next `.readyToPlay` transition should auto-play.
    /// Defaults to play; the reload path captures the user's current
    /// play/pause state so a paused user isn't unpaused by a bitrate change.
    private var autoPlayPolicy = AutoPlayPolicy()

    nonisolated deinit {
        DebugLog.playback("🗑️ VideoPlayerViewModel deinit")
    }

    // MARK: - Loading

    func loadVideoURL() async {
        DebugLog.playback("🎬 loadVideoURL() — item: \(item.name)")

        guard !isLoadingVideo else {
            DebugLog.playback("⚠️ Video already loading, skipping duplicate request")
            return
        }
        isLoadingVideo = true
        isLoading = true
        errorMessage = nil

        // Home-tab carousels (Resume / Latest) ship sparse MediaItems
        // without MediaSources. Without that, `PlaybackStreamURLBuilder`
        // can't do codec analysis → falls through to forced transcode,
        // and `PlaybackInfoBuilder` renders "Video: Unknown". Refetch the
        // full item before handing it to the URL builder.
        await refetchFullItemIfNeeded()

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

    /// Replace `self.item` with the server's full record when the input is
    /// missing MediaSources. No-op when MediaSources is already populated
    /// (avoids a wasted round-trip for the Detail-view → Play path, where
    /// `getItemDetails` already brought them in).
    private func refetchFullItemIfNeeded() async {
        guard item.mediaSources?.isEmpty ?? true else { return }
        guard !userId.isEmpty else {
            DebugLog.playback("⚠️ Cannot refetch item: missing userId")
            return
        }

        // Reuses the app-level `JellyfinAPIClient` so this fetch shares the
        // existing HTTP/2 connection pool and URLCache rather than opening a
        // second pool every Play. The injected client is already configured
        // by the auth flow — no per-call configure() needed.
        do {
            let full = try await apiClient.getItemDetails(userId: userId, itemId: item.id)
            let sourceCount = full.mediaSources?.count ?? 0
            let streamCount = full.mediaSources?.first?.mediaStreams?.count ?? 0
            DebugLog.playback("🔁 Refetched '\(full.name)' with \(sourceCount) MediaSource(s), \(streamCount) MediaStream(s)")
            self.item = full
        } catch {
            DebugLog.playback("⚠️ getItemDetails failed for '\(item.name)': \(error). Continuing with sparse item — playback will likely fall back to transcode.")
        }
    }

    /// Shared startup path used by both initial load and transcode failover.
    private func startPlayback(url: URL, mode: PlaybackMode) async {
        DebugLog.playback("🎬 LOADING VIDEO — \(item.name) (\(mode.rawValue))")
        // Transcode URLs include the access token in the query string —
        // never log the absolute URL outside DEBUG. Host alone is enough
        // to triage "wrong server" vs other failure modes.
        DebugLog.playback("🔗 URL host: \(url.host ?? "?")")
        #if DEBUG
        DebugLog.playback("🔗 Full URL: \(url.absoluteString)")
        #endif

        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetHTTPHeaderFieldsKey": ["X-Emby-Token": accessToken]
        ])
        // Preload the keys AVPlayerItem will block on anyway. Doing it
        // before construction lets the load happen concurrently with our
        // own setup work below (service binding, KVO, time observers),
        // shaving ~100–300ms off the `waitForPlayerItemReady` gate. On
        // failure we log and keep going — `AVPlayerItem.status == .failed`
        // still surfaces the underlying error to the existing error path.
        do {
            _ = try await asset.load(.isPlayable, .duration, .tracks)
        } catch {
            DebugLog.playback("⚠️ AVURLAsset key preload failed: \(error.localizedDescription). Continuing — AVPlayerItem will surface its own error.")
        }
        let playerItem = AVPlayerItem(asset: asset)
        playerItem.preferredForwardBufferDuration = 10.0
        playerItem.preferredMaximumResolution = Self.preferredMaximumResolution()

        let avPlayer = AVPlayer(playerItem: playerItem)
        avPlayer.appliesMediaSelectionCriteriaAutomatically = true

        // Flip the shared audio session into playback mode. Cheap on
        // subsequent Plays — AudioManager caches the category transition.
        AudioManager.shared.enterPlaybackMode()

        self.player = avPlayer
        observeDefaultRate(on: avPlayer)

        // Build / rebind services for this playback session.
        sessionReporter = PlaybackSessionReporter(
            baseURL: baseURL,
            accessToken: accessToken,
            item: item,
            userId: userId
        )
        bindIntroController()
        bindSubtitleManager()
        bindNowPlaying()
        bindLifecycleController()

        setupTimeObserver()
        setupPlayerObservers(playerItem: playerItem)

        // Arm failover (no-op if mode is already transcode — the controller
        // checks internally).
        failoverController.arm(playerItem: playerItem) { [weak self] in
            await self?.retryWithTranscode()
        }

        await waitForPlayerItemReady(playerItem: playerItem)

        if playerItem.status == .failed {
            DebugLog.playback("❌ Player item failed during initial load")
            // The pre-flight HEAD probe used to surface 404/auth here. Now we
            // rely on AVFoundation's own error surfacing — `errorLog()` carries
            // a structured event ring that includes the upstream HTTP status
            // and a server comment, which is enough to triage 404/401 etc.
            if let lastErrorEvent = playerItem.errorLog()?.events.last {
                DebugLog.playback("   errorLog: domain=\(lastErrorEvent.errorDomain) status=\(lastErrorEvent.errorStatusCode) comment=\(lastErrorEvent.errorComment ?? "nil")")
            }
            errorMessage = playerItem.error.map { "Playback failed: \($0.localizedDescription)" }
                ?? "Video playback failed with unknown error"
            self.player = nil
            isLoading = false
            isLoadingVideo = false
            return
        }

        if playerItem.status == .readyToPlay {
            if let resumePosition = getResumePosition() {
                DebugLog.playback("⏩ Seeking to resume position: \(formatTime(resumePosition))")
                let seekTime = CMTime(seconds: resumePosition, preferredTimescale: 600)
                await withCheckedContinuation { continuation in
                    avPlayer.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                        continuation.resume()
                    }
                }
            }
            subtitleManager?.configure(player: avPlayer)
        }

        isLoading = false
        isLoadingVideo = false

        // `reportStart` is an advisory POST whose response the client never
        // reads, and `fetchMarkers` updates overlays that aren't visible at
        // t=0 — neither belongs on the first-frame critical path. Detaching
        // saves ~500–1000ms TTFP per Play (audit Finding 1).
        if playerItem.status == .readyToPlay {
            let reporter = sessionReporter
            let intro = introController
            let position = currentTime
            Task { await reporter?.reportStart(positionSeconds: position, mode: mode) }
            Task { await intro?.fetchMarkers() }
        }
    }

    private func retryWithTranscode() async {
        DebugLog.playback("🔄 Retrying playback with transcode mode...")
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
        controller.$showSkipCreditsButton
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.showSkipCreditsButton = $0 }
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

    /// Bind the lifecycle controller to the current playback session.
    /// Rebuilt on each session (mid-playback stream reloads tear down
    /// and rebuild the player) so the callbacks always point at the
    /// current player via `self`.
    private func bindLifecycleController() {
        lifecycleController?.stop()
        let controller = PlaybackLifecycleController(
            isPlaying: { [weak self] in self?.isPlaying ?? false },
            pause: { [weak self] in self?.pausePlayback() },
            resume: { [weak self] in self?.startPlayback() }
        )
        lifecycleController = controller
        controller.start()
    }

    private func bindNowPlaying() {
        nowPlaying = NowPlayingPublisher(
            item: item,
            baseURL: baseURL,
            handlers: NowPlayingPublisher.Handlers(
                play: { [weak self] in self?.startPlayback() },
                pause: { [weak self] in self?.pausePlayback() },
                togglePlayPause: { [weak self] in self?.togglePlayPause() },
                seekForward: { [weak self] in self?.seekForward() },
                seekBackward: { [weak self] in self?.seekBackward() },
                seek: { [weak self] pos in
                    guard let self = self, let player = self.player else { return }
                    player.seek(to: CMTime(seconds: pos, preferredTimescale: 600))
                }
            )
        )
    }

    // MARK: - View-facing actions

    func skipIntro() {
        introController?.skip(player: player)
    }

    func skipCredits() {
        introController?.skipCredits(player: player)
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
        DebugLog.playback("🧹 Cleaning up VideoPlayerViewModel")

        let progressPercent = (duration > 0) ? (currentTime / duration) * 100.0 : 0.0
        let wasCompleted = progressPercent >= 90.0
        DebugLog.playback("📊 Final position: \(formatTime(currentTime)) / \(formatTime(duration)) (\(String(format: "%.1f", progressPercent))%)")

        let mode = failoverController.currentMode ?? .directPlay
        let position = currentTime
        let reporter = sessionReporter

        // Without a background task, the player-view tear-down can race the
        // OS suspending the app and the in-flight POST gets cancelled silently
        // — the precise reason a previous Avatar:TLAB session never showed up
        // in Continue Watching even though the position was correct.
        let bgTaskName = "playback-stop"
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        bgTask = UIApplication.shared.beginBackgroundTask(withName: bgTaskName) {
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }

        Task {
            await reporter?.reportStopped(positionSeconds: position, completed: wasCompleted, mode: mode)
            if wasCompleted {
                await reporter?.markAsWatched()
            }
            await MainActor.run {
                if bgTask != .invalid {
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = .invalid
                }
            }
        }

        failoverController.cancel()
        nowPlaying = nil  // deinit clears MPNowPlayingInfoCenter
        lifecycleController?.stop()
        lifecycleController = nil
        cleanupAVResources()
        // Notify other apps that the playback session ended so any audio
        // they had ducked can resume. Category stays cached for the next
        // Play so we don't repay the `setCategory` cost.
        AudioManager.shared.exitPlaybackMode()
    }

    private func cleanupAVResources() {
        cancellables.removeAll()
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        defaultRateObservation?.invalidate()
        defaultRateObservation = nil
        progressReportTimer?.invalidate()
        progressReportTimer = nil
        player?.pause()
        player = nil
    }

    /// KVO bridge from `AVPlayer.defaultRate` (Cocoa property, not Combine
    /// publishable on its own) into the `playbackRate` `@Published` field.
    /// Drives SwiftUI invalidation so `updateUIViewController` re-runs and
    /// `syncPlaybackRateMenu` rebuilds the speedometer menu with a fresh
    /// checkmark on the active rate.
    private func observeDefaultRate(on player: AVPlayer) {
        defaultRateObservation?.invalidate()
        playbackRate = player.defaultRate > 0 ? player.defaultRate : 1.0
        defaultRateObservation = player.observe(
            \.defaultRate,
             options: [.initial, .new]
        ) { [weak self] player, _ in
            let next = player.defaultRate > 0 ? player.defaultRate : 1.0
            Task { @MainActor [weak self] in
                guard let self, self.playbackRate != next else { return }
                self.playbackRate = next
            }
        }
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
                self.nowPlaying?.update(
                    elapsed: currentSeconds,
                    duration: durationSeconds,
                    rate: player.rate
                )
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
                    DebugLog.playback("✅ Player item is ready to play")
                    Task { @MainActor in
                        guard let player = self.player else { return }
                        if let resumePosition = self.getResumePosition() {
                            DebugLog.playback("⏩ [Status Observer] Seeking to resume: \(self.formatTime(resumePosition))")
                            let seekTime = CMTime(seconds: resumePosition, preferredTimescale: 600)
                            await withCheckedContinuation { continuation in
                                player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero) { _ in
                                    continuation.resume()
                                }
                            }
                        }
                        if self.autoPlayPolicy.consume() {
                            player.play()
                        }
                        let mode = self.failoverController.currentMode ?? .directPlay
                        await self.sessionReporter?.reportStart(positionSeconds: self.currentTime, mode: mode)
                        await self.introController?.fetchMarkers()
                        self.subtitleManager?.configure(player: player)
                    }
                case .failed:
                    if let error = playerItem.error {
                        DebugLog.playback("❌ Player item failed: \(error.localizedDescription)")
                        self.errorMessage = error.localizedDescription
                    }
                case .unknown:
                    DebugLog.playback("⏳ Player item status unknown")
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
                    DebugLog.playback("❌ Player error: \(error.localizedDescription)")
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
                    DebugLog.playback("❌ Failed to play to end time: \(error.localizedDescription)")
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
                    DebugLog.playback("⚠️ Still loading after 30s, but continuing (HLS may still work)")
                    return
                }
            @unknown default:
                break
            }
        }
    }

    // MARK: - Helpers

    private func getResumePosition() -> Double? {
        // Explicit caller intent takes precedence over userData auto-resume.
        // `pending == 0` is a deliberate "Play from Beginning" signal from
        // the detail screen — return 0 (not nil) so we do NOT fall through
        // to the userData path.
        if let pending = pendingSeekOnReload {
            pendingSeekOnReload = nil
            return pending
        }
        guard let userData = item.userData,
              let position = userData.playbackPositionTicks,
              let total = item.runTimeTicks else {
            return nil
        }
        let progress = Double(position) / Double(total) * 100.0
        let seconds = Double(position) / 10_000_000.0
        return (progress > 1.0 && progress < 95.0) ? seconds : nil
    }

    private func getDeviceId() -> String { DeviceIdentifier.current() }

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

    // MARK: - HLS variant ceiling

    /// Cap HLS variant selection to the display's native pixel resolution so 1080p
    /// Apple TVs don't pull the 4K rendition (wasted bandwidth + wasted decode).
    /// `nativeBounds` is in pixels and is already in landscape orientation on tvOS.
    private static func preferredMaximumResolution() -> CGSize {
        let nativeBounds = UIScreen.main.nativeBounds
        return CGSize(width: nativeBounds.width, height: nativeBounds.height)
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
