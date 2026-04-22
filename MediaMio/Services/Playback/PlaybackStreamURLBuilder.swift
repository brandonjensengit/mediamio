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
        print("🎬 Building streaming URL for: \(item.name)")

        let fileSize = item.mediaSources?.first?.size ?? 0
        let fileSizeGB = Double(fileSize) / 1_000_000_000.0
        print("📁 File size: \(String(format: "%.2f", fileSizeGB)) GB")

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

        let streamingMode = StreamingMode(rawValue: settingsManager.streamingMode) ?? .auto
        print("📊 Streaming mode: \(streamingMode.rawValue)")

        let codecSupport = AppleTVCodecSupport.shared
        let bestMode = codecSupport.getBestPlaybackMode(for: item)
        print("🎯 Best playback mode: \(bestMode.rawValue)")

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

    // MARK: - Mode dispatchers

    private func buildAuto(bestMode: PlaybackMode, fileSizeGB: Double) -> Result? {
        switch bestMode {
        case .directPlay:
            if let url = buildDirectPlayURL() {
                return Result(url: url, mode: .directPlay)
            }
            print("⚠️ Direct Play failed, trying Direct Stream")
            fallthrough

        case .directStream:
            if let url = buildDirectStreamURL() {
                return Result(url: url, mode: .directStream)
            }
            print("⚠️ Direct Stream failed, trying Remux")
            fallthrough

        case .remux:
            if let url = buildRemuxURL() {
                return Result(url: url, mode: .remux)
            }
            print("⚠️ Remux failed, falling back to transcode")
            fallthrough

        case .transcode:
            if fileSizeGB > 25 {
                print("💡 Large file (\(String(format: "%.1f", fileSizeGB)) GB) - transcode will load faster")
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
            print("⚠️ Direct Play not possible, using Direct Stream instead")
            return Result(url: url, mode: .directStream)
        }
        print("⚠️ Neither Direct Play nor Direct Stream available, falling back to transcoding")
        if let url = buildTranscodeURL() {
            return Result(url: url, mode: .transcode)
        }
        return nil
    }

    // MARK: - Mode builders (verbatim from original VideoPlayerViewModel)

    private func buildDirectPlayURL() -> URL? {
        print("💎 Attempting Direct Play - HLS with hardware decoding")

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
            URLQueryItem(name: "SegmentLength", value: "3"),
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),
            URLQueryItem(name: "SubtitleMethod", value: "Encode"),
            URLQueryItem(name: "SubtitleCodec", value: "webvtt"),
            URLQueryItem(name: "VerticalTextPosition", value: "90"),
            URLQueryItem(name: "SubtitleProfile", value: "default")
        ]

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
            URLQueryItem(name: "SegmentLength", value: "3"),
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),
            URLQueryItem(name: "SubtitleMethod", value: "Encode"),
            URLQueryItem(name: "SubtitleCodec", value: "webvtt"),
            URLQueryItem(name: "VerticalTextPosition", value: "90"),
            URLQueryItem(name: "SubtitleProfile", value: "default")
        ]

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
            URLQueryItem(name: "SegmentLength", value: "3"),
            URLQueryItem(name: "EnableAutoStreamCopy", value: "true"),
            URLQueryItem(name: "CopyTimestamps", value: "true"),
            URLQueryItem(name: "RequireNonAnamorphic", value: "false"),
            URLQueryItem(name: "SubtitleMethod", value: "Encode"),
            URLQueryItem(name: "SubtitleCodec", value: "webvtt"),
            URLQueryItem(name: "VerticalTextPosition", value: "90"),
            URLQueryItem(name: "SubtitleProfile", value: "default")
        ]

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

        var components = URLComponents(string: baseURL)
        components?.path = "/Videos/\(item.id)/master.m3u8"

        let videoCodec = VideoCodec(rawValue: settingsManager.videoCodec)?.jellyfinValue ?? "h264"
        let maxBitrate = settingsManager.maxBitrate
        let mbps = Double(maxBitrate) / 1_000_000.0

        let audioBitrate = 640_000
        let videoBitrate = min(maxBitrate - audioBitrate, 15_000_000)
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
            print("📝 Adding subtitle track: index=\(subtitleIndex)")
        }

        components?.queryItems = queryItems

        guard let url = components?.url else {
            print("❌ Failed to construct transcode URL")
            return nil
        }

        print("🎬 Transcode URL: \(url.absoluteString)")
        return url
    }
}
