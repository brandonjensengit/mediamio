//
//  Settings.swift
//  MediaMio
//
//  Settings models and enums
//

import Foundation
import SwiftUI

// MARK: - Video Quality

enum VideoQuality: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case uhd4K = "4K Ultra HD"
    case fullHD = "1080p Full HD"
    case hd = "720p HD"
    case sd = "480p SD"

    var id: String { rawValue }

    var maxHeight: Int? {
        switch self {
        case .auto: return nil
        case .uhd4K: return 2160
        case .fullHD: return 1080
        case .hd: return 720
        case .sd: return 480
        }
    }

    var description: String {
        switch self {
        case .auto: return "Automatically adjust quality based on connection"
        case .uhd4K: return "Best quality, requires fast connection (25+ Mbps)"
        case .fullHD: return "Excellent quality (5-8 Mbps)"
        case .hd: return "Good quality (2-5 Mbps)"
        case .sd: return "Lower quality, saves bandwidth (<2 Mbps)"
        }
    }
}

// MARK: - Audio Quality

enum AudioQuality: String, CaseIterable, Identifiable {
    case lossless = "Lossless"
    case high = "High Quality"
    case standard = "Standard"

    var id: String { rawValue }

    var bitrate: Int {
        switch self {
        case .lossless: return 0 // No transcoding
        case .high: return 640000
        case .standard: return 192000
        }
    }

    var description: String {
        switch self {
        case .lossless: return "Preserve original audio (TrueHD, DTS-HD)"
        case .high: return "AAC 5.1 Surround (640 kbps)"
        case .standard: return "AAC Stereo (192 kbps)"
        }
    }
}

// MARK: - Resume Behavior

enum ResumeBehavior: String, CaseIterable, Identifiable {
    case alwaysAsk = "Always Ask"
    case alwaysResume = "Always Resume"
    case neverResume = "Start from Beginning"

    var id: String { rawValue }
}

// MARK: - Streaming Mode

enum StreamingMode: String, CaseIterable, Identifiable {
    case directPlay = "Direct Play"
    case directStream = "Direct Stream"
    case transcode = "Transcode"
    case auto = "Auto"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .directPlay: return "Play original file without any processing (best quality)"
        case .directStream: return "Change container format only (maintains quality)"
        case .transcode: return "Convert video on server (compatibility mode)"
        case .auto: return "Let MediaMio choose based on format support"
        }
    }

    var jellyfinValue: String {
        switch self {
        case .directPlay: return "DirectPlay"
        case .directStream: return "DirectStream"
        case .transcode: return "Transcode"
        case .auto: return "Auto"
        }
    }
}

// MARK: - Video Codec

enum VideoCodec: String, CaseIterable, Identifiable {
    case h264 = "H.264/AVC"
    case hevc = "HEVC/H.265"
    case vp9 = "VP9"
    case av1 = "AV1"

    var id: String { rawValue }

    var jellyfinValue: String {
        switch self {
        case .h264: return "h264"
        case .hevc: return "hevc"
        case .vp9: return "vp9"
        case .av1: return "av1"
        }
    }

    var description: String {
        switch self {
        case .h264: return "Universal compatibility, larger file sizes"
        case .hevc: return "50% smaller files, newer devices only"
        case .vp9: return "Google's codec, good for web streaming"
        case .av1: return "Next-gen codec, best compression"
        }
    }
}

// MARK: - Subtitle Settings

enum SubtitleMode: String, CaseIterable, Identifiable {
    case off = "Off by Default"
    case on = "On by Default"
    case foreignOnly = "Foreign Language Only"
    case smart = "Smart (Match Audio)"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .off: return "Subtitles off unless manually enabled"
        case .on: return "Subtitles always on in preferred language"
        case .foreignOnly: return "Only when audio is foreign language"
        case .smart: return "Auto-enable if audio doesn't match preferred language"
        }
    }
}

enum SubtitleSize: String, CaseIterable, Identifiable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case extraLarge = "Extra Large"

    var id: String { rawValue }

    var scaleFactor: CGFloat {
        switch self {
        case .small: return 0.8
        case .medium: return 1.0
        case .large: return 1.2
        case .extraLarge: return 1.5
        }
    }
}

// MARK: - Skip Settings

enum SkipBehavior: String, CaseIterable, Identifiable {
    case alwaysSkip = "Always Skip"
    case buttonWithDelay = "Button + Auto-Skip"
    case buttonOnly = "Button Only"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .alwaysSkip: return "Skip immediately without prompt"
        case .buttonWithDelay: return "Show button, auto-skip after countdown"
        case .buttonOnly: return "Show button, require manual skip"
        }
    }
}

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case dark = "Dark"
    case extraDark = "Extra Dark"
    case oledBlack = "OLED Black"

    var id: String { rawValue }

    var backgroundColor: Color {
        switch self {
        case .dark: return Color(red: 0.04, green: 0.04, blue: 0.04)
        case .extraDark: return Color(red: 0, green: 0, blue: 0)
        case .oledBlack: return Color.black
        }
    }
}
