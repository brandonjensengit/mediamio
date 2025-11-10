//
//  AppleTVCodecSupport.swift
//  MediaMio
//
//  Detects which codecs Apple TV can decode natively using hardware
//

import Foundation
import AVFoundation

class AppleTVCodecSupport {
    static let shared = AppleTVCodecSupport()

    // MARK: - Supported Codecs

    /// Video codecs that Apple TV can decode in hardware
    private let supportedVideoCodecs: Set<String> = [
        // H.264/AVC
        "h264", "avc", "avc1",

        // HEVC/H.265
        "hevc", "h265", "hvc1", "hev1",

        // VP9
        "vp9", "vp09",

        // MPEG-4
        "mpeg4"
    ]

    /// Audio codecs that Apple TV can decode natively
    private let supportedAudioCodecs: Set<String> = [
        // AAC variants
        "aac", "mp4a",

        // MP3
        "mp3", "mp3a",

        // Dolby
        "ac3", "eac3", "ec-3",

        // Lossless
        "flac", "alac",

        // PCM
        "pcm", "pcm_s16le", "pcm_s24le"
    ]

    /// Containers that Apple TV supports natively
    private let supportedContainers: Set<String> = [
        "mp4", "m4v", "mov", "ts", "m2ts"
    ]

    // MARK: - Codec Detection

    /// Check if a video codec is supported by Apple TV hardware
    func isVideoCodecSupported(_ codec: String?) -> Bool {
        guard let codec = codec?.lowercased() else { return false }
        return supportedVideoCodecs.contains(codec)
    }

    /// Check if an audio codec is supported natively
    func isAudioCodecSupported(_ codec: String?) -> Bool {
        guard let codec = codec?.lowercased() else { return false }
        return supportedAudioCodecs.contains(codec)
    }

    /// Check if a container format is supported
    func isContainerSupported(_ container: String?) -> Bool {
        guard let container = container?.lowercased() else { return false }
        return supportedContainers.contains(container)
    }

    // MARK: - Playback Capability

    /// Determine the best playback mode for a media item
    func getBestPlaybackMode(for item: MediaItem) -> PlaybackMode {
        guard let mediaSource = item.mediaSources?.first else {
            print("⚠️ No media source - defaulting to transcode")
            return .transcode
        }

        let container = mediaSource.container
        let videoStream = mediaSource.mediaStreams?.first(where: { $0.type?.lowercased() == "video" })
        let audioStream = mediaSource.mediaStreams?.first(where: { $0.type?.lowercased() == "audio" })

        let videoCodec = videoStream?.codec
        let audioCodec = audioStream?.codec

        print("📊 Codec Analysis:")
        print("   Container: \(container ?? "unknown")")
        print("   Video Codec: \(videoCodec ?? "unknown")")
        print("   Audio Codec: \(audioCodec ?? "unknown")")

        let videoSupported = isVideoCodecSupported(videoCodec)
        let audioSupported = isAudioCodecSupported(audioCodec)
        let containerSupported = isContainerSupported(container)

        print("   Video Supported: \(videoSupported ? "✅" : "❌")")
        print("   Audio Supported: \(audioSupported ? "✅" : "❌")")
        print("   Container Supported: \(containerSupported ? "✅" : "❌")")

        // Decision tree for best mode
        if videoSupported && audioSupported && containerSupported {
            print("💎 DIRECT PLAY - All formats natively supported!")
            return .directPlay
        } else if videoSupported && audioSupported && !containerSupported {
            print("📦 REMUX - Need container change only (MKV→MP4)")
            return .remux
        } else if videoSupported && !audioSupported {
            print("🔊 DIRECT STREAM - Video native, transcode audio only")
            return .directStream
        } else {
            print("⚙️ TRANSCODE - Video codec not supported, full transcode needed")
            return .transcode
        }
    }

    /// Check if Direct Play is possible (everything supported)
    func canDirectPlay(_ item: MediaItem) -> Bool {
        return getBestPlaybackMode(for: item) == .directPlay
    }

    /// Check if Direct Stream is possible (video supported, audio needs transcode)
    func canDirectStream(_ item: MediaItem) -> Bool {
        let mode = getBestPlaybackMode(for: item)
        return mode == .directStream || mode == .remux
    }
}

// MARK: - Playback Mode

enum PlaybackMode: String {
    case directPlay = "Direct Play"
    case directStream = "Direct Stream"
    case remux = "Remux"
    case transcode = "Transcode"

    var description: String {
        switch self {
        case .directPlay:
            return "Original file, hardware decoded on Apple TV (Best Quality, 0% Server CPU)"
        case .directStream:
            return "Original video + transcoded audio, hardware decoded (Excellent Quality, 5-10% Server CPU)"
        case .remux:
            return "Container change only (MKV→MP4), hardware decoded (Excellent Quality, 10-20% Server CPU)"
        case .transcode:
            return "Full re-encode on server (Reduced Quality, 80-100% Server CPU)"
        }
    }
}
