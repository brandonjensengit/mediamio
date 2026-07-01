//
//  PlaybackStreamURLBuilder.swift
//  MediaMio
//
//  Phase A refactor: extracted from VideoPlayerViewModel (lines 257–750 of the
//  original 1830-line god-object). Pure value-type. Builds the Jellyfin
//  streaming URL for a media item under a given streaming mode.
//
//  Constraint: never imports AVKit. Never holds mutable state. The output is
//  a function of the inputs only — making it trivially unit-testable
//  (PlaybackStreamURLBuilderTests).
//

import Foundation

/// Builds a Jellyfin HLS streaming URL for a `MediaItem`, choosing the right
/// playback mode (Direct Play → Direct Stream → Remux → Transcode) based on
/// codec support, file size, and the user's streaming-mode setting.
struct PlaybackStreamURLBuilder {
    let item: MediaItem
    let baseURL: String
    let accessToken: String
    let deviceId: String
    let settingsManager: SettingsManager

    /// The result of building a streaming URL, including the playback mode
    /// the URL was constructed for. Callers need the mode to (a) report the
    /// correct `PlayMethod` to Jellyfin and (b) suppress the failover timer
    /// when already in transcode mode.
    struct Result {
        let url: URL
        let mode: PlaybackMode
    }

    /// Top-level entry point. Returns `nil` if every URL construction path
    /// fails (extremely rare — only on malformed `baseURL`).
    func build() -> Result? {
        DebugLog.playback("🎬 Building streaming URL for: \(item.name)")

        let fileSize = item.mediaSources?.first?.size ?? 0
        let fileSizeGB = Double(fileSize) / 1_000_000_000.0
        DebugLog.playback("📁 File size: \(String(format: "%.2f", fileSizeGB)) GB")

        if let mediaSource = item.mediaSources?.first {
            DebugLog.playback("📦 Container: \(mediaSource.container ?? "unknown")")
            DebugLog.playback("📊 Bitrate: \(mediaSource.bitrate ?? 0) bps")

            if let mediaStreams = mediaSource.mediaStreams {
                for stream in mediaStreams {
                    if stream.type?.lowercased() == "video" {
                        DebugLog.playback("🎥 Video stream: codec=\(stream.codec ?? "unknown"), \(stream.width ?? 0)x\(stream.height ?? 0)")
                    } else if stream.type?.lowercased() == "audio" {
                        DebugLog.playback("🔊 Audio stream: codec=\(stream.codec ?? "unknown")")
                    }
                }
            } else {
                DebugLog.playback("⚠️ No mediaStreams data available")
            }
        } else {
            DebugLog.playback("⚠️ No mediaSources data available")
        }

        let streamingMode = StreamingMode(rawValue: settingsManager.streamingMode) ?? .auto
        DebugLog.playback("📊 Streaming mode: \(streamingMode.rawValue)")

        let codecSupport = AppleTVCodecSupport.shared
        let bestMode = codecSupport.getBestPlaybackMode(for: item)
        DebugLog.playback("🎯 Best playback mode: \(bestMode.rawValue)")

        switch streamingMode {
        case .auto:
            return buildAuto(bestMode: bestMode, fileSizeGB: fileSizeGB)
        case .directPlay:
            return buildForcedDirectPlay(codecSupport: codecSupport)
        default:
            // Forced transcode (any mode that isn't .auto or .directPlay).
            if let url = buildTranscodeURL() {
                return Result(url: url, mode: .transcode)
            }
            return nil
        }
    }

    /// Skip the bestMode auto-pick and produce a transcode URL directly.
    /// Used by the failover path: when a DirectPlay/Stream/Remux attempt
    /// got AVPlayer to `.readyToPlay` but couldn't actually decode video,
    /// re-running `build()` produces the same failing URL because the
    /// builder is stateless and still sees the source as remux-eligible.
    /// This entry point is the only safe way to force transcode at runtime
    /// without mutating user settings.
    func buildForcedTranscode() -> Result? {
        DebugLog.playback("🔁 Forcing transcode mode (failover override)")
        guard let url = buildTranscodeURL() else { return nil }
        return Result(url: url, mode: .transcode)
    }

    // MARK: - Mode dispatchers

    private func buildAuto(bestMode: PlaybackMode, fileSizeGB: Double) -> Result? {
        switch bestMode {
        case .directPlay:
            if let url = buildDirectPlayURL() {
                return Result(url: url, mode: .directPlay)
            }
            DebugLog.playback("⚠️ Direct Play failed, trying Direct Stream")
            fallthrough

        case .directStream:
            if let url = buildDirectStreamURL() {
                return Result(url: url, mode: .directStream)
            }
            DebugLog.playback("⚠️ Direct Stream failed, trying Remux")
            fallthrough

        case .remux:
            if let url = buildRemuxURL() {
                return Result(url: url, mode: .remux)
            }
            DebugLog.playback("⚠️ Remux failed, falling back to transcode")
            fallthrough

        case .transcode:
            if fileSizeGB > 25 {
                DebugLog.playback("💡 Large file (\(String(format: "%.1f", fileSizeGB)) GB) - transcode will load faster")
            }
            if let url = buildTranscodeURL() {
                return Result(url: url, mode: .transcode)
            }
            return nil
        }
    }

    private func buildForcedDirectPlay(codecSupport: AppleTVCodecSupport) -> Result? {
        if codecSupport.canDirectPlay(item), let url = buildDirectPlayURL() {
            return Result(url: url, mode: .directPlay)
        }
        if codecSupport.canDirectStream(item), let url = buildDirectStreamURL() {
            DebugLog.playback("⚠️ Direct Play not possible, using Direct Stream instead")
            return Result(url: url, mode: .directStream)
        }
        DebugLog.playback("⚠️ Neither Direct Play nor Direct Stream available, falling back to transcoding")
        if let url = buildTranscodeURL() {
            return Result(url: url, mode: .transcode)
        }
        return nil
    }

    // MARK: - Mode builders (verbatim from original VideoPlayerViewModel)

    private func buildDirectPlayURL() -> URL? {
        DebugLog.playback("💎 Attempting Direct Play - HLS with hardware decoding")

        if let mediaSource = item.mediaSources?.first {
            DebugLog.playback("📦 Original container: \(mediaSource.container ?? "unknown")")

            if let mediaStreams = mediaSource.mediaStreams {
                for stream in mediaStreams {
                    if stream.type?.lowercased() == "video" {
                        let codec = stream.codec ?? "unknown"
                        let resolution = "\(stream.width ?? 0)x\(stream.height ?? 0)"
                        DebugLog.playback("🎥 Video codec: \(codec) @ \(resolution)")
                    } else if stream.type?.lowercased() == "audio" {
                        let codec = stream.codec ?? "unknown"
                        DebugLog.playback("🔊 Audio codec: \(codec)")
                    }
                }
            }
        }

        var components = URLComponents(string: baseURL)
        components?.path = "/Videos/\(item.id)/master.m3u8"

        let maxBitrate = settingsManager.maxBitrate

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "VideoCodec", value: "copy"),
            URLQueryItem(name: "AudioCodec", value: "copy"),
            URLQueryItem(name: "MaxStreamingBitrate", value: "\(maxBitrate)"),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "MediaSourceId", value: item.id),
            URLQueryItem(name: "DeviceId", value: deviceId),
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "Container", value: "ts"),
            // SegmentContainer=mp4 forces Jellyfin to emit HLSv7 with
            // fMP4 fragments + an EXT-X-MAP init segment. Apple's HLS
            // spec since tvOS 12 disallows HEVC in MPEG-TS — without
            // this flag Jellyfin sometimes returns a single-variant
            // manifest with hvc1-in-.ts and AVPlayer parses the
            // playlist (gets duration) but never loads any segments,
            // hanging at status=unknown with 0 tracks. The fMP4 path
            // is the spec-compliant HEVC HLS transport.
            URLQueryItem(name: "SegmentContainer", value: "mp4"),
            URLQueryItem(name: "SegmentLength", value: "3"),
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),
            URLQueryItem(name: "SubtitleMethod", value: "Hls"),
            URLQueryItem(name: "SubtitleCodec", value: "webvtt"),
            URLQueryItem(name: "VerticalTextPosition", value: "90"),
            URLQueryItem(name: "SubtitleProfile", value: "default")
        ]

        if let subtitleIndex = item.firstSubtitleIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: "\(subtitleIndex)"))
            DebugLog.playback("📝 DirectPlay: Adding subtitle track index=\(subtitleIndex)")
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            DebugLog.playback("❌ Failed to construct Direct Play URL")
            return nil
        }

        DebugLog.playback("🎬 Using URL: \(url.absoluteString)")
        DebugLog.playback("💎 DIRECT PLAY - HLS streaming, hardware decoded, 0% server CPU")
        DebugLog.playback("   VideoCodec: copy (no transcoding)")
        DebugLog.playback("   AudioCodec: copy (no transcoding)")
        DebugLog.playback("   Container: ts (MPEG Transport Stream)")
        DebugLog.playback("   Max Bitrate: \(String(format: "%.1f", Double(maxBitrate) / 1_000_000.0)) Mbps")
        return url
    }

    private func buildDirectStreamURL() -> URL? {
        DebugLog.playback("🔊 Using Direct Stream - video native, transcode audio only")

        var components = URLComponents(string: baseURL)
        components?.path = "/Videos/\(item.id)/master.m3u8"

        let maxBitrate = settingsManager.maxBitrate

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "VideoCodec", value: "copy"),
            URLQueryItem(name: "AudioCodec", value: "aac"),
            URLQueryItem(name: "MaxStreamingBitrate", value: "\(maxBitrate)"),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "MediaSourceId", value: item.id),
            URLQueryItem(name: "DeviceId", value: deviceId),
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "Container", value: "ts,mp4"),
            // See comment in buildDirectPlayURL — fMP4 segments are
            // required when video is hvc1/HEVC.
            URLQueryItem(name: "SegmentContainer", value: "mp4"),
            URLQueryItem(name: "SegmentLength", value: "3"),
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),
            URLQueryItem(name: "SubtitleMethod", value: "Hls"),
            URLQueryItem(name: "SubtitleCodec", value: "webvtt"),
            URLQueryItem(name: "VerticalTextPosition", value: "90"),
            URLQueryItem(name: "SubtitleProfile", value: "default")
        ]

        if let subtitleIndex = item.firstSubtitleIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: "\(subtitleIndex)"))
            DebugLog.playback("📝 DirectStream: Adding subtitle track index=\(subtitleIndex)")
        }

        components?.queryItems = queryItems

        let url = components?.url
        DebugLog.playback("🔗 Direct Stream URL: \(url?.absoluteString ?? "nil")")
        DebugLog.playback("💪 Apple TV hardware will decode video, 5-10% server CPU for audio")
        return url
    }

    private func buildRemuxURL() -> URL? {
        DebugLog.playback("📦 Using Remux - container change only (MKV→MP4)")

        var components = URLComponents(string: baseURL)
        components?.path = "/Videos/\(item.id)/master.m3u8"

        let maxBitrate = settingsManager.maxBitrate

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "VideoCodec", value: "copy"),
            URLQueryItem(name: "AudioCodec", value: "copy"),
            URLQueryItem(name: "MaxStreamingBitrate", value: "\(maxBitrate)"),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "MediaSourceId", value: item.id),
            URLQueryItem(name: "DeviceId", value: deviceId),
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "Container", value: "mp4,ts"),
            // See comment in buildDirectPlayURL — fMP4 segments are
            // required when video is hvc1/HEVC, and the Remux path is
            // exactly where 4K HEVC HDR sources land.
            URLQueryItem(name: "SegmentContainer", value: "mp4"),
            URLQueryItem(name: "SegmentLength", value: "3"),
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),
            URLQueryItem(name: "SubtitleMethod", value: "Hls"),
            URLQueryItem(name: "SubtitleCodec", value: "webvtt"),
            URLQueryItem(name: "VerticalTextPosition", value: "90"),
            URLQueryItem(name: "SubtitleProfile", value: "default")
        ]

        if let subtitleIndex = item.firstSubtitleIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: "\(subtitleIndex)"))
            DebugLog.playback("📝 Remux: Adding subtitle track index=\(subtitleIndex)")
        }

        components?.queryItems = queryItems

        let url = components?.url
        DebugLog.playback("🔗 Remux URL: \(url?.absoluteString ?? "nil")")
        DebugLog.playback("⚡ Fast container change, 10-20% server CPU, maximum quality")
        return url
    }

    private func buildTranscodeURL() -> URL? {
        DebugLog.playback("⚠️ Using transcoding - quality may be reduced")

        var components = URLComponents(string: baseURL)
        components?.path = "/Videos/\(item.id)/master.m3u8"

        let videoCodec = VideoCodec(rawValue: settingsManager.videoCodec)?.jellyfinValue ?? "h264"
        let maxBitrate = settingsManager.maxBitrate
        let mbps = Double(maxBitrate) / 1_000_000.0

        let audioBitrate = 640_000
        let videoBitrate = min(maxBitrate - audioBitrate, 15_000_000)
        let videoMbps = Double(videoBitrate) / 1_000_000.0
        let audioKbps = Double(audioBitrate) / 1_000.0

        DebugLog.playback("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        DebugLog.playback("📊 TRANSCODE SETTINGS")
        DebugLog.playback("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        DebugLog.playback("📊 Total bitrate: \(String(format: "%.0f", mbps)) Mbps")
        DebugLog.playback("📊 Video bitrate: \(String(format: "%.1f", videoMbps)) Mbps (determines resolution!)")
        DebugLog.playback("📊 Audio bitrate: \(String(format: "%.0f", audioKbps)) Kbps")
        DebugLog.playback("📊 Video codec: \(videoCodec)")

        if maxBitrate != 120_000_000 {
            DebugLog.playback("⚠️ WARNING: Bitrate is NOT 120 Mbps!")
            DebugLog.playback("⚠️ Current: \(String(format: "%.0f", mbps)) Mbps")
        }

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "VideoCodec", value: videoCodec),
            URLQueryItem(name: "AudioCodec", value: "aac,mp3,ac3,eac3"),
            URLQueryItem(name: "MaxStreamingBitrate", value: "\(maxBitrate)"),
            URLQueryItem(name: "VideoBitrate", value: "\(videoBitrate)"),
            URLQueryItem(name: "AudioBitrate", value: "\(audioBitrate)"),
            URLQueryItem(name: "PlaySessionId", value: UUID().uuidString),
            URLQueryItem(name: "MediaSourceId", value: item.id),
            URLQueryItem(name: "DeviceId", value: deviceId),
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "MaxWidth", value: "1920"),
            URLQueryItem(name: "MaxHeight", value: "1080"),
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),
            URLQueryItem(name: "Profile", value: "high"),
            URLQueryItem(name: "Level", value: "41"),
            URLQueryItem(name: "Container", value: "ts,mp4"),
            URLQueryItem(name: "SegmentLength", value: "3"),
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),
            URLQueryItem(name: "SubtitleMethod", value: "Encode"),
            URLQueryItem(name: "SubtitleCodec", value: "webvtt"),
            URLQueryItem(name: "VerticalTextPosition", value: "90"),
            URLQueryItem(name: "SubtitleProfile", value: "default")
        ]

        if let subtitleIndex = item.firstSubtitleIndex {
            queryItems.append(URLQueryItem(name: "SubtitleStreamIndex", value: "\(subtitleIndex)"))
            DebugLog.playback("📝 Adding subtitle track: index=\(subtitleIndex)")
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            DebugLog.playback("❌ Failed to construct transcode URL")
            return nil
        }

        DebugLog.playback("🎬 Transcode URL: \(url.absoluteString)")
        return url
    }
}
