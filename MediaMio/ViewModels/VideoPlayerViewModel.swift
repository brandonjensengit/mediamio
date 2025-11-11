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

    // Fallback state
    private var currentPlaybackMode: PlaybackMode?
    private var hasFallbackAttempted: Bool = false
    private var fallbackCheckTask: Task<Void, Never>?

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
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎬 loadVideoURL() CALLED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📺 Item: \(item.name)")
        print("🆔 Item ID: \(item.id)")
        print("📝 Subtitles: \(item.hasSubtitles ? "YES (\(item.subtitleStreams.count) tracks)" : "NO")")
        if item.hasSubtitles {
            for stream in item.subtitleStreams {
                print("   - Index \(stream.index ?? -1): \(stream.subtitleDisplayName) (\(stream.language ?? "unknown"))")
            }
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

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

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🎬 LOADING VIDEO")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📺 Title: \(item.name)")
            print("🔗 URL: \(streamURL.absoluteString)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

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
                    if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length") {
                        print("✅ Content-Length: \(contentLength) bytes")
                    }

                    if httpResponse.statusCode != 200 && httpResponse.statusCode != 206 {
                        print("❌ Invalid HTTP status code: \(httpResponse.statusCode)")
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
                print("⚠️ Continuing anyway (some servers don't support HEAD)")
                // Don't abort - some servers don't support HEAD
            }

            // Create AVPlayer with asset that includes auth headers
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🎬 CREATING AVPlayer")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            let asset = AVURLAsset(url: streamURL, options: [
                "AVURLAssetHTTPHeaderFieldsKey": [
                    "X-Emby-Token": accessToken
                ]
            ])

            print("✅ Created AVURLAsset with auth headers")
            let playerItem = AVPlayerItem(asset: asset)

            // CRITICAL: Configure buffering for faster loading
            playerItem.preferredForwardBufferDuration = 10.0  // Buffer 10 seconds ahead
            print("⚡ Configured 10-second forward buffer for fast loading")

            let avPlayer = AVPlayer(playerItem: playerItem)

            // CRITICAL: Enable automatic media selection for subtitles
            avPlayer.appliesMediaSelectionCriteriaAutomatically = true
            print("✅ Enabled automatic media selection criteria")

            // Set audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)

            self.player = avPlayer

            // Setup observers
            setupTimeObserver()
            setupPlayerObservers(playerItem: playerItem)

            // Setup automatic fallback if playback fails
            setupPlaybackFallback(playerItem: playerItem)

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
        print("🎬 Building streaming URL for: \(item.name)")

        // Get file size
        let fileSize = item.mediaSources?.first?.size ?? 0
        let fileSizeGB = Double(fileSize) / 1_000_000_000.0
        print("📁 File size: \(String(format: "%.2f", fileSizeGB)) GB")

        // Log media stream details
        if let mediaSource = item.mediaSources?.first {
            print("📦 Container: \(mediaSource.container ?? "unknown")")
            print("📊 Bitrate: \(mediaSource.bitrate ?? 0) bps")

            if let mediaStreams = mediaSource.mediaStreams {
                for stream in mediaStreams {
                    if stream.type?.lowercased() == "video" {
                        print("🎥 Video stream: codec=\(stream.codec ?? "unknown"), \(stream.width ?? 0)x\(stream.height ?? 0)")
                    } else if stream.type?.lowercased() == "audio" {
                        print("🔊 Audio stream: codec=\(stream.codec ?? "unknown")")
                    }
                }
            } else {
                print("⚠️ No mediaStreams data available")
            }
        } else {
            print("⚠️ No mediaSources data available")
        }

        // Check streaming mode setting
        let streamingMode = StreamingMode(rawValue: settingsManager.streamingMode) ?? .auto
        print("📊 Streaming mode: \(streamingMode.rawValue)")

        // Use codec detection to determine best playback mode
        let codecSupport = AppleTVCodecSupport.shared
        let bestMode = codecSupport.getBestPlaybackMode(for: item)
        print("🎯 Best playback mode: \(bestMode.rawValue)")

        // Smart streaming strategy based on codec support and file size
        if streamingMode == .auto {
            // Use codec-based decision for best quality/performance
            switch bestMode {
            case .directPlay:
                // Everything supported - direct play!
                if let directPlayURL = buildDirectPlayURL() {
                    currentPlaybackMode = .directPlay
                    return directPlayURL
                }
                print("⚠️ Direct Play failed, trying Direct Stream")
                fallthrough

            case .directStream:
                // Video supported, audio needs transcode
                if let directStreamURL = buildDirectStreamURL() {
                    currentPlaybackMode = .directStream
                    return directStreamURL
                }
                print("⚠️ Direct Stream failed, trying Remux")
                fallthrough

            case .remux:
                // Need container change (MKV→MP4)
                if let remuxURL = buildRemuxURL() {
                    currentPlaybackMode = .remux
                    return remuxURL
                }
                print("⚠️ Remux failed, falling back to transcode")
                fallthrough

            case .transcode:
                // Need full transcode
                // For large files, transcode might actually be faster
                if fileSizeGB > 25 {
                    print("💡 Large file (\(String(format: "%.1f", fileSizeGB)) GB) - transcode will load faster")
                }
                currentPlaybackMode = .transcode
                return buildTranscodeURL()
            }
        }
        // Manual mode selection
        else if streamingMode == .directPlay {
            // Force Direct Play (or try Direct Stream if that fails)
            if codecSupport.canDirectPlay(item), let directPlayURL = buildDirectPlayURL() {
                currentPlaybackMode = .directPlay
                return directPlayURL
            } else if codecSupport.canDirectStream(item), let directStreamURL = buildDirectStreamURL() {
                print("⚠️ Direct Play not possible, using Direct Stream instead")
                currentPlaybackMode = .directStream
                return directStreamURL
            }
            print("⚠️ Neither Direct Play nor Direct Stream available, falling back to transcoding")
            currentPlaybackMode = .transcode
            return buildTranscodeURL()
        }
        else {
            // Force transcode
            currentPlaybackMode = .transcode
            return buildTranscodeURL()
        }
    }

    private func buildDirectPlayURL() -> URL? {
        print("💎 Attempting Direct Play - HLS with hardware decoding")

        // Log original file codecs
        if let mediaSource = item.mediaSources?.first {
            print("📦 Original container: \(mediaSource.container ?? "unknown")")

            if let mediaStreams = mediaSource.mediaStreams {
                for stream in mediaStreams {
                    if stream.type?.lowercased() == "video" {
                        let codec = stream.codec ?? "unknown"
                        let resolution = "\(stream.width ?? 0)x\(stream.height ?? 0)"
                        print("🎥 Video codec: \(codec) @ \(resolution)")
                    } else if stream.type?.lowercased() == "audio" {
                        let codec = stream.codec ?? "unknown"
                        print("🔊 Audio codec: \(codec)")
                    }
                }
            }
        }

        // Use HLS endpoint instead of Download for better streaming
        var components = URLComponents(string: baseURL)
        components?.path = "/Videos/\(item.id)/master.m3u8"

        let maxBitrate = settingsManager.maxBitrate

        // Build query items - COPY both video and audio (no re-encoding!)
        var queryItems: [URLQueryItem] = [
            // CRITICAL: Copy both streams for true Direct Play
            URLQueryItem(name: "VideoCodec", value: "copy"),
            URLQueryItem(name: "AudioCodec", value: "copy"),

            URLQueryItem(name: "MaxStreamingBitrate", value: "\(maxBitrate)"),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "MediaSourceId", value: item.id),
            URLQueryItem(name: "DeviceId", value: getDeviceId()),
            URLQueryItem(name: "api_key", value: accessToken),

            // Container and streaming settings
            URLQueryItem(name: "Container", value: "ts"),
            URLQueryItem(name: "SegmentLength", value: "3"),
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),

            // Preserve timestamps and aspect ratio
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),

            // Subtitle support - External creates separate subtitle file
            URLQueryItem(name: "SubtitleMethod", value: "External"),
            URLQueryItem(name: "SubtitleCodec", value: "vtt")
        ]

        // Add SubtitleStreamIndex if available
        if let subtitleIndex = item.firstSubtitleIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: "\(subtitleIndex)"))
            print("📝 DirectPlay: Adding subtitle track index=\(subtitleIndex)")
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            print("❌ Failed to construct Direct Play URL")
            return nil
        }

        print("🎬 Using URL: \(url.absoluteString)")
        print("💎 DIRECT PLAY - HLS streaming, hardware decoded, 0% server CPU")
        print("   VideoCodec: copy (no transcoding)")
        print("   AudioCodec: copy (no transcoding)")
        print("   Container: ts (MPEG Transport Stream)")
        print("   Max Bitrate: \(String(format: "%.1f", Double(maxBitrate) / 1_000_000.0)) Mbps")
        return url
    }

    private func buildDirectStreamURL() -> URL? {
        print("🔊 Using Direct Stream - video native, transcode audio only")

        // Use Jellyfin's HLS for direct streaming
        var components = URLComponents(string: baseURL)
        components?.path = "/Videos/\(item.id)/master.m3u8"

        let maxBitrate = settingsManager.maxBitrate

        // Build query items - COPY video, transcode audio
        var queryItems: [URLQueryItem] = [
            // CRITICAL: Copy video stream (no re-encoding!)
            URLQueryItem(name: "VideoCodec", value: "copy"),

            // Transcode audio to AAC (universally supported)
            URLQueryItem(name: "AudioCodec", value: "aac"),

            URLQueryItem(name: "MaxStreamingBitrate", value: "\(maxBitrate)"),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "MediaSourceId", value: item.id),
            URLQueryItem(name: "DeviceId", value: getDeviceId()),
            URLQueryItem(name: "api_key", value: accessToken),

            // Container and streaming settings
            URLQueryItem(name: "Container", value: "ts,mp4"),
            URLQueryItem(name: "SegmentLength", value: "3"),
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),

            // Preserve timestamps and aspect ratio
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),

            // Subtitle support - External creates separate subtitle file
            URLQueryItem(name: "SubtitleMethod", value: "External"),
            URLQueryItem(name: "SubtitleCodec", value: "vtt")
        ]

        // Add SubtitleStreamIndex if available
        if let subtitleIndex = item.firstSubtitleIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: "\(subtitleIndex)"))
            print("📝 DirectStream: Adding subtitle track index=\(subtitleIndex)")
        }

        components?.queryItems = queryItems

        let url = components?.url
        print("🔗 Direct Stream URL: \(url?.absoluteString ?? "nil")")
        print("💪 Apple TV hardware will decode video, 5-10% server CPU for audio")
        return url
    }

    private func buildRemuxURL() -> URL? {
        print("📦 Using Remux - container change only (MKV→MP4)")

        // Use Jellyfin's HLS for remuxing
        var components = URLComponents(string: baseURL)
        components?.path = "/Videos/\(item.id)/master.m3u8"

        let maxBitrate = settingsManager.maxBitrate

        // Build query items - COPY everything, just change container
        var queryItems: [URLQueryItem] = [
            // CRITICAL: Copy both video and audio streams
            URLQueryItem(name: "VideoCodec", value: "copy"),
            URLQueryItem(name: "AudioCodec", value: "copy"),

            URLQueryItem(name: "MaxStreamingBitrate", value: "\(maxBitrate)"),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "MediaSourceId", value: item.id),
            URLQueryItem(name: "DeviceId", value: getDeviceId()),
            URLQueryItem(name: "api_key", value: accessToken),

            // Change container to MP4/TS (from MKV)
            URLQueryItem(name: "Container", value: "mp4,ts"),
            URLQueryItem(name: "SegmentLength", value: "3"),
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),

            // Preserve everything
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),

            // Subtitle support - External creates separate subtitle file
            URLQueryItem(name: "SubtitleMethod", value: "External"),
            URLQueryItem(name: "SubtitleCodec", value: "vtt")
        ]

        // Add SubtitleStreamIndex if available
        if let subtitleIndex = item.firstSubtitleIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: "\(subtitleIndex)"))
            print("📝 Remux: Adding subtitle track index=\(subtitleIndex)")
        }

        components?.queryItems = queryItems

        let url = components?.url
        print("🔗 Remux URL: \(url?.absoluteString ?? "nil")")
        print("⚡ Fast container change, 10-20% server CPU, maximum quality")
        return url
    }

    private func buildTranscodeURL() -> URL? {
        print("⚠️ Using transcoding - quality may be reduced")

        // Use Jellyfin's HLS master playlist for adaptive streaming with transcoding
        var components = URLComponents(string: baseURL)
        components?.path = "/Videos/\(item.id)/master.m3u8"

        // Apply settings from SettingsManager
        let videoCodec = VideoCodec(rawValue: settingsManager.videoCodec)?.jellyfinValue ?? "h264"
        let maxBitrate = settingsManager.maxBitrate
        let mbps = Double(maxBitrate) / 1_000_000.0

        // CRITICAL: Calculate VideoBitrate for desired resolution
        // Jellyfin uses VideoBitrate to determine output resolution, NOT MaxWidth/MaxHeight
        // For 1080p transcoding, we need 10-15 Mbps video bitrate
        // Reserve bitrate for audio
        let audioBitrate = 640_000  // 640 kbps for high quality audio
        let videoBitrate = min(maxBitrate - audioBitrate, 15_000_000)  // Cap at 15 Mbps for 1080p
        let videoMbps = Double(videoBitrate) / 1_000_000.0
        let audioKbps = Double(audioBitrate) / 1_000.0

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 TRANSCODE SETTINGS")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 Total bitrate: \(String(format: "%.0f", mbps)) Mbps")
        print("📊 Video bitrate: \(String(format: "%.1f", videoMbps)) Mbps (determines resolution!)")
        print("📊 Audio bitrate: \(String(format: "%.0f", audioKbps)) Kbps")
        print("📊 Video codec: \(videoCodec)")

        if maxBitrate != 120_000_000 {
            print("⚠️ WARNING: Bitrate is NOT 120 Mbps!")
            print("⚠️ Current: \(String(format: "%.0f", mbps)) Mbps")
            print("⚠️ Expected: 120 Mbps")
            print("⚠️ This will cause blurry video!")
        }

        if mbps < 40 {
            print("❌ CRITICAL: Bitrate too low for HD content! (\(String(format: "%.0f", mbps)) Mbps)")
            print("❌ Minimum recommended: 80 Mbps")
            print("❌ Optimal: 120 Mbps")
        } else if mbps >= 120 {
            print("✅ Bitrate excellent for 4K content")
        } else if mbps >= 80 {
            print("⚠️ Bitrate acceptable for 1080p, but 120 Mbps recommended")
        } else {
            print("⚠️ Bitrate low - may cause quality issues")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Build query items with settings
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "VideoCodec", value: videoCodec),
            URLQueryItem(name: "AudioCodec", value: "aac,mp3,ac3,eac3"),  // Support more audio codecs
            URLQueryItem(name: "MaxStreamingBitrate", value: "\(maxBitrate)"),

            // CRITICAL: VideoBitrate determines output resolution!
            // Jellyfin calculates resolution based on this value, NOT MaxWidth/MaxHeight
            // 8-15 Mbps produces 1080p output
            URLQueryItem(name: "VideoBitrate", value: "\(videoBitrate)"),
            URLQueryItem(name: "AudioBitrate", value: "\(audioBitrate)"),

            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "MediaSourceId", value: item.id),
            URLQueryItem(name: "DeviceId", value: getDeviceId()),
            URLQueryItem(name: "api_key", value: accessToken),

            // MaxWidth/MaxHeight as upper limits (aspect ratio preserved)
            URLQueryItem(name: "MaxWidth", value: "1920"),
            URLQueryItem(name: "MaxHeight", value: "1080"),

            // CRITICAL: Fix aspect ratio / zoom issues
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),
            URLQueryItem(name: "Profile", value: "high"),  // Use high quality H.264 profile
            URLQueryItem(name: "Level", value: "41"),  // H.264 Level 4.1 for 1080p
            URLQueryItem(name: "Container", value: "ts,mp4"),
            URLQueryItem(name: "SegmentLength", value: "3"),

            // Enable auto stream copy when possible
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),

            // CRITICAL: Subtitle support for HLS
            // External creates separate .vtt subtitle file for proper rendering
            URLQueryItem(name: "SubtitleMethod", value: "External"),  // External subtitle file
            URLQueryItem(name: "SubtitleCodec", value: "vtt")    // VTT format for HLS
        ]

        // CRITICAL: Add SubtitleStreamIndex to tell Jellyfin which subtitle track to include
        if let subtitleIndex = item.firstSubtitleIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: "\(subtitleIndex)"))
            print("📝 Adding subtitle track: index=\(subtitleIndex)")
        } else {
            print("⚠️ No subtitle streams found in media item")
        }

        print("✅ High quality transcode configuration:")
        print("   - VideoBitrate: \(String(format: "%.1f", videoMbps)) Mbps (→ produces 1080p output)")
        print("   - AudioBitrate: \(String(format: "%.0f", audioKbps)) Kbps")
        print("   - MaxWidth/MaxHeight: 1920x1080 (upper limits)")
        print("   - CopyTimestamps: true (preserves original timing)")
        print("   - RequireNonAnamorphic: false (allows anamorphic/widescreen)")
        print("   - Profile: high (H.264 high profile)")
        print("   - Level: 4.1 (supports 1080p @ high bitrate)")
        print("   - SubtitleMethod: External (separate subtitle file)")
        print("   - SubtitleCodec: vtt (WebVTT format)")
        print("   📝 NOTE: External subtitles should render as regular sbtl, not CC")
        print("   📝 NOTE: VideoBitrate parameter tells Jellyfin what resolution to produce")
        print("   📝 8-15 Mbps video bitrate = 1080p output, aspect ratio preserved")
        print("   📝 Subtitles will be available via native AVPlayer selector")

        components?.queryItems = queryItems

        guard let url = components?.url else {
            print("❌ Failed to construct transcode URL")
            return nil
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔗 TRANSCODE URL CONSTRUCTED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🎬 Using URL: \(url.absoluteString)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 VERIFY CRITICAL PARAMETERS IN URL:")

        // Verify VideoBitrate (THE MOST CRITICAL PARAMETER!)
        if url.absoluteString.contains("VideoBitrate=\(videoBitrate)") {
            print("✅ VideoBitrate=\(videoBitrate) CONFIRMED (→ will produce 1080p)")
            print("   This is the parameter that determines output resolution!")
        } else if url.absoluteString.contains("VideoBitrate=") {
            print("⚠️ VideoBitrate FOUND but with different value")
        } else {
            print("❌ CRITICAL: VideoBitrate MISSING - this causes 416x172 output!")
        }

        // Verify AudioBitrate
        if url.absoluteString.contains("AudioBitrate=\(audioBitrate)") {
            print("✅ AudioBitrate=\(audioBitrate) CONFIRMED")
        }

        // Verify total bitrate
        if url.absoluteString.contains("MaxStreamingBitrate=120000000") {
            print("✅ MaxStreamingBitrate=120000000 CONFIRMED in URL")
        } else if url.absoluteString.contains("MaxStreamingBitrate=") {
            // Extract the actual value from URL
            if let range = url.absoluteString.range(of: "MaxStreamingBitrate="),
               let endRange = url.absoluteString[range.upperBound...].range(of: "&") {
                let bitrateString = url.absoluteString[range.upperBound..<endRange.lowerBound]
                print("❌ WRONG BITRATE IN URL: MaxStreamingBitrate=\(bitrateString)")
                if let bitrateValue = Int(bitrateString) {
                    let actualMbps = Double(bitrateValue) / 1_000_000.0
                    print("❌ Actual bitrate: \(String(format: "%.0f", actualMbps)) Mbps")
                    print("❌ Expected: 120 Mbps")
                }
            } else {
                // Try to find it at the end of URL (no & after)
                if let range = url.absoluteString.range(of: "MaxStreamingBitrate=") {
                    let bitrateString = String(url.absoluteString[range.upperBound...])
                    print("❌ WRONG BITRATE IN URL: MaxStreamingBitrate=\(bitrateString)")
                    if let bitrateValue = Int(bitrateString.components(separatedBy: "&").first ?? "") {
                        let actualMbps = Double(bitrateValue) / 1_000_000.0
                        print("❌ Actual bitrate: \(String(format: "%.0f", actualMbps)) Mbps")
                        print("❌ Expected: 120 Mbps")
                    }
                }
            }
        } else {
            print("❌ MaxStreamingBitrate NOT FOUND in URL!")
        }

        // Verify aspect ratio protection parameters
        if url.absoluteString.contains("CopyTimestamps=true") {
            print("✅ CopyTimestamps=true CONFIRMED")
        } else {
            print("❌ CopyTimestamps=true MISSING - aspect ratio may be wrong!")
        }

        if url.absoluteString.contains("RequireNonAnamorphic=false") {
            print("✅ RequireNonAnamorphic=false CONFIRMED")
        } else {
            print("❌ RequireNonAnamorphic=false MISSING - may crop/zoom video!")
        }

        if url.absoluteString.contains("Profile=high") {
            print("✅ Profile=high CONFIRMED (H.264 high profile)")
        } else {
            print("⚠️ Profile=high MISSING - lower quality encoding")
        }

        // Verify MaxWidth/MaxHeight parameters (resolution limits)
        if url.absoluteString.contains("MaxWidth=1920") {
            print("✅ MaxWidth=1920 CONFIRMED (1080p width limit)")
        } else {
            print("⚠️ MaxWidth=1920 NOT FOUND in URL")
        }

        if url.absoluteString.contains("MaxHeight=1080") {
            print("✅ MaxHeight=1080 CONFIRMED (1080p height limit)")
        } else {
            print("⚠️ MaxHeight=1080 NOT FOUND in URL")
        }

        if url.absoluteString.contains("Level=41") {
            print("✅ Level=41 CONFIRMED (H.264 Level 4.1)")
        } else {
            print("⚠️ Level=41 NOT FOUND in URL")
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

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
            print("⚠️ configureSubtitles: No player or player item")
            return
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📝 SUBTITLE CONFIGURATION")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Log subtitle information from MediaItem
        print("📊 MediaItem subtitle info:")
        print("   - Has subtitles: \(item.hasSubtitles)")
        print("   - Subtitle streams count: \(item.subtitleStreams.count)")
        for stream in item.subtitleStreams {
            print("   - Stream index=\(stream.index ?? -1), lang=\(stream.language ?? "?"), codec=\(stream.codec ?? "?"), external=\(stream.isExternal ?? false)")
        }

        // Get available subtitle tracks from AVPlayer
        guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            print("❌ AVPlayer: No legible media selection group found")
            print("❌ This means Jellyfin did NOT include subtitles in the HLS stream")
            print("❌ Check that SubtitleStreamIndex parameter is being added to URL")
            return
        }

        print("✅ AVPlayer detected \(group.options.count) subtitle tracks")

        // CRITICAL: Check if subtitle tracks are properly formatted
        print("🔍 Detailed subtitle track analysis:")
        for (index, option) in group.options.enumerated() {
            print("   Track \(index):")
            print("      Display name: \(option.displayName)")
            print("      Locale: \(option.locale?.identifier ?? "NONE")")
            print("      Language: \(option.locale?.languageCode ?? "NONE")")
            print("      Characteristics: \(option.mediaType)")
            print("      Has SDH: \(option.hasMediaCharacteristic(.describesMusicAndSoundForAccessibility))")
            print("      Has forced: \(option.hasMediaCharacteristic(.isAuxiliaryContent))")
            print("      Extendedlanguage tag: \(option.extendedLanguageTag ?? "none")")

            if let asset = playerItem.asset as? AVURLAsset {
                print("      Asset URL contains subtitle: \(asset.url.absoluteString.contains("SubtitleStreamIndex"))")
            }
        }

        // Populate available subtitles
        availableSubtitles = group.options.enumerated().map { index, option in
            print("   - Track \(index): \(option.displayName) (\(option.locale?.languageCode ?? "unknown"))")
            return SubtitleTrack(
                index: index,
                displayName: option.displayName,
                languageCode: option.locale?.languageCode ?? "unknown",
                option: option
            )
        }

        let subtitleMode = SubtitleMode(rawValue: settingsManager.subtitleMode) ?? .off
        print("📊 Subtitle mode setting: \(subtitleMode.rawValue)")
        print("📊 Default subtitle language: \(settingsManager.defaultSubtitleLanguage)")

        switch subtitleMode {
        case .off:
            // CHANGED: Enable first subtitle if available (was: disable all)
            // User can still disable via native controls if they don't want subtitles
            print("⚠️ Subtitle mode is OFF, but enabling first track anyway")
            print("   (User can disable via native AVPlayer controls)")
            if let firstOption = group.options.first {
                playerItem.select(firstOption, in: group)
                selectedSubtitleIndex = 0
                print("✅ Enabled first subtitle: \(firstOption.displayName)")
            } else {
                playerItem.select(nil, in: group)
                selectedSubtitleIndex = nil
                print("❌ No subtitles to enable")
            }

        case .on, .foreignOnly, .smart:
            // Enable subtitles based on default language setting
            let defaultLang = settingsManager.defaultSubtitleLanguage
            print("🔍 Looking for subtitle with language: \(defaultLang)")

            // Try to find matching language
            let matchingOption = group.options.enumerated().first { _, option in
                if let locale = option.locale {
                    let matches = locale.languageCode == defaultLang
                    print("   Checking: \(option.displayName) (\(locale.languageCode ?? "?")), matches: \(matches)")
                    return matches
                }
                print("   Checking: \(option.displayName) (no locale)")
                return false
            }

            if let (index, option) = matchingOption {
                playerItem.select(option, in: group)
                selectedSubtitleIndex = index
                print("✅ Enabled matching subtitle: \(option.displayName) at index \(index)")
            } else if let firstOption = group.options.first {
                playerItem.select(firstOption, in: group)
                selectedSubtitleIndex = 0
                print("⚠️ No language match, enabling first subtitle: \(firstOption.displayName)")
            } else {
                print("❌ No subtitles available to enable")
            }
        }

        // CRITICAL: Verify subtitle is actually selected
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🔍 VERIFYING SUBTITLE SELECTION")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        if let currentSelection = playerItem.currentMediaSelection.selectedMediaOption(in: group) {
            print("✅ Currently selected subtitle: \(currentSelection.displayName)")
            print("   Locale: \(currentSelection.locale?.identifier ?? "none")")
            print("   Language code: \(currentSelection.locale?.languageCode ?? "none")")
            print("   Has accessible content: \(currentSelection.hasMediaCharacteristic(.describesMusicAndSoundForAccessibility))")
        } else {
            print("❌ NO SUBTITLE IS CURRENTLY SELECTED!")
            print("❌ This means playerItem.select() didn't work!")
            print("❌ Trying to force selection again...")

            // Try forcing selection one more time
            if let firstOption = group.options.first {
                print("🔄 Force-selecting first subtitle again: \(firstOption.displayName)")
                playerItem.select(firstOption, in: group)

                // Check again
                if let verification = playerItem.currentMediaSelection.selectedMediaOption(in: group) {
                    print("✅ Force selection worked: \(verification.displayName)")
                } else {
                    print("❌ Force selection STILL FAILED")
                    print("❌ This is a bug in AVPlayer or the HLS stream")
                }
            }
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }

    func selectSubtitle(at index: Int?) {
        guard let player = player, let playerItem = player.currentItem else {
            print("⚠️ selectSubtitle: No player or player item")
            return
        }

        guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            print("⚠️ selectSubtitle: No legible media selection group")
            return
        }

        if let index = index, index >= 0 && index < group.options.count {
            // Enable subtitle at index
            let option = group.options[index]
            print("📝 Selecting subtitle at index \(index): \(option.displayName)")
            playerItem.select(option, in: group)
            selectedSubtitleIndex = index
            print("✅ Subtitle selected successfully")
        } else {
            // Disable subtitles
            print("📝 Disabling subtitles (index=nil)")
            playerItem.select(nil, in: group)
            selectedSubtitleIndex = nil
            print("✅ Subtitles disabled")
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
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("🔍 PLAYER STATUS CHANGED")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                let statusString: String
                switch status {
                case .unknown:
                    statusString = "UNKNOWN (0)"
                case .readyToPlay:
                    statusString = "READY_TO_PLAY (1)"
                case .failed:
                    statusString = "FAILED (2)"
                @unknown default:
                    statusString = "UNKNOWN_NEW (\(status.rawValue))"
                }
                print("📊 Status: \(statusString)")

                // Log player item details
                if let asset = playerItem.asset as? AVURLAsset {
                    print("🔗 URL: \(asset.url.absoluteString)")
                }
                print("⏱️  Duration: \(playerItem.duration.seconds)s")
                print("📺 Tracks: \(playerItem.tracks.count)")

                // Log any error details
                if let error = playerItem.error {
                    let nsError = error as NSError
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    print("❌ ERROR DETAILS:")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ Domain: \(nsError.domain)")
                    print("❌ Code: \(nsError.code)")
                    print("❌ UserInfo: \(nsError.userInfo)")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                }

                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                switch status {
                case .readyToPlay:
                    print("✅ Player item is ready to play")
                    if let duration = self?.player?.currentItem?.duration.seconds {
                        print("✅ Duration: \(duration)s")
                    }

                    // DIAGNOSTIC: Check for video and audio tracks
                    if let item = self?.player?.currentItem {
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        print("🔍 DIAGNOSTIC: Checking tracks")
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                        print("📺 Total tracks: \(item.tracks.count)")

                        // Check for video tracks
                        let videoTracks = item.tracks.filter { track in
                            if let assetTrack = track.assetTrack {
                                return assetTrack.mediaType == .video
                            }
                            return false
                        }
                        print("🎥 Video tracks: \(videoTracks.count)")
                        for (index, track) in videoTracks.enumerated() {
                            if let assetTrack = track.assetTrack {
                                print("   Video track \(index): enabled=\(track.isEnabled), nominalFrameRate=\(assetTrack.nominalFrameRate), dimensions=\(assetTrack.naturalSize)")
                                print("   Codec: \(assetTrack.mediaType.rawValue)")
                            }
                        }

                        // Check for audio tracks
                        let audioTracks = item.tracks.filter { track in
                            if let assetTrack = track.assetTrack {
                                return assetTrack.mediaType == .audio
                            }
                            return false
                        }
                        print("🔊 Audio tracks: \(audioTracks.count)")
                        for (index, track) in audioTracks.enumerated() {
                            if let assetTrack = track.assetTrack {
                                print("   Audio track \(index): enabled=\(track.isEnabled)")
                            }
                        }

                        // Check presentation size
                        print("📐 Presentation size: \(item.presentationSize)")

                        if videoTracks.isEmpty {
                            print("❌ CRITICAL: NO VIDEO TRACKS FOUND!")
                            print("❌ This is why there's no video but sound works!")
                        } else if videoTracks.allSatisfy({ !$0.isEnabled }) {
                            print("❌ CRITICAL: Video tracks exist but ALL DISABLED!")
                            print("❌ This is why there's no video but sound works!")
                        } else if item.presentationSize == .zero {
                            print("⚠️ WARNING: Presentation size is zero!")
                            print("⚠️ Video may not render properly!")
                        } else {
                            print("✅ Video tracks present and enabled")
                        }
                        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
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
                    let nsError = error as NSError
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    print("❌ PLAYER ERROR DETECTED")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ Domain: \(nsError.domain)")
                    print("❌ Code: \(nsError.code)")
                    print("❌ UserInfo: \(nsError.userInfo)")

                    // Check for common error codes
                    if nsError.domain == "AVFoundationErrorDomain" {
                        switch nsError.code {
                        case -11800:
                            print("❌ Error type: Failed to load media (unsupported format or network issue)")
                        case -11828:
                            print("❌ Error type: Cannot decode (codec not supported)")
                        case -11850:
                            print("❌ Error type: Unsupported format")
                        default:
                            print("❌ Error type: Unknown AVFoundation error")
                        }
                    }
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

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

    private func setupPlaybackFallback(playerItem: AVPlayerItem) {
        // Cancel any existing fallback task
        fallbackCheckTask?.cancel()

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🛡️ AUTOMATIC FALLBACK ENABLED")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🛡️ Current mode: \(currentPlaybackMode?.rawValue ?? "unknown")")
        print("🛡️ Will check status after 3 seconds")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        // Start a 3-second timer to check for playback failure
        fallbackCheckTask = Task { @MainActor in
            // Wait 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            guard !Task.isCancelled else {
                print("🛡️ Fallback check cancelled")
                return
            }

            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("🛡️ FALLBACK CHECK (after 3 seconds)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📊 Player item status: \(playerItem.status.rawValue)")
            print("📊 Current mode: \(self.currentPlaybackMode?.rawValue ?? "unknown")")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

            // Check if playback failed
            if playerItem.status == .failed {
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("❌ PLAYBACK FAILED - INITIATING FALLBACK")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                if let error = playerItem.error {
                    let nsError = error as NSError
                    print("❌ Error: \(error.localizedDescription)")
                    print("❌ Domain: \(nsError.domain)")
                    print("❌ Code: \(nsError.code)")
                    print("❌ UserInfo: \(nsError.userInfo)")
                }

                // Log current URL
                if let asset = playerItem.asset as? AVURLAsset {
                    print("❌ Failed URL: \(asset.url.absoluteString)")
                }

                // Check if we're already in transcode mode
                if self.currentPlaybackMode == .transcode {
                    print("❌ Already in transcode mode, cannot fallback further")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    self.errorMessage = "Playback failed: \(playerItem.error?.localizedDescription ?? "Unknown error")"
                    return
                }

                // Check if we've already attempted fallback
                if self.hasFallbackAttempted {
                    print("❌ Fallback already attempted, not retrying")
                    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    return
                }

                // Attempt fallback to transcode
                print("🔄 Initiating automatic fallback to transcode mode...")
                self.hasFallbackAttempted = true
                self.errorMessage = "Switched to compatibility mode for better playback"
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

                // Retry with transcode
                await self.retryWithTranscode()
            } else if playerItem.status == .readyToPlay {
                print("✅ Playback successful - no fallback needed")
            } else {
                print("⏳ Playback still loading after 3 seconds (status: \(playerItem.status.rawValue))")
            }
        }
    }

    private func retryWithTranscode() async {
        print("🔄 Retrying playback with transcode mode...")

        // Clean up current player
        cleanup()

        // Force transcode mode
        currentPlaybackMode = .transcode

        // Rebuild URL with transcode
        guard let transcodeURL = buildTranscodeURL() else {
            print("❌ Failed to build transcode URL")
            errorMessage = "Failed to retry playback"
            return
        }

        // Reload video with transcode URL
        do {
            isLoading = true
            isLoadingVideo = true

            let asset = AVURLAsset(url: transcodeURL, options: [
                "AVURLAssetHTTPHeaderFieldsKey": [
                    "X-Emby-Token": accessToken
                ]
            ])

            print("✅ Creating player item with transcode URL...")
            let playerItem = AVPlayerItem(asset: asset)

            // Configure buffering
            playerItem.preferredForwardBufferDuration = 10.0

            let avPlayer = AVPlayer(playerItem: playerItem)

            // CRITICAL: Enable automatic media selection for subtitles
            avPlayer.appliesMediaSelectionCriteriaAutomatically = true
            print("✅ Fallback: Enabled automatic media selection criteria")

            // Set audio session
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)

            self.player = avPlayer

            // Setup observers (but don't setup fallback again!)
            setupTimeObserver()
            setupPlayerObservers(playerItem: playerItem)

            // Wait for player item to be ready
            print("⏳ Waiting for transcode player item to be ready...")
            await waitForPlayerItemReady(playerItem: playerItem)

            if playerItem.status == .failed {
                print("❌ Transcode also failed")
                errorMessage = "Playback failed: \(playerItem.error?.localizedDescription ?? "Unknown error")"
                self.player = nil
                isLoading = false
                isLoadingVideo = false
                return
            }

            if playerItem.status == .readyToPlay {
                print("✅ Transcode successful, starting playback")
                isLoading = false
                isLoadingVideo = false
                avPlayer.play()
                await reportPlaybackStart()
            }
        } catch {
            print("❌ Error during transcode retry: \(error)")
            errorMessage = "Failed to retry playback: \(error.localizedDescription)"
            isLoading = false
            isLoadingVideo = false
        }
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
