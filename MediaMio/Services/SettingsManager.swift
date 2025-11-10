//
//  SettingsManager.swift
//  MediaMio
//
//  Manages all app settings and preferences
//

import Foundation
import SwiftUI
import Combine

class SettingsManager: ObservableObject {
    // MARK: - Video Settings
    @AppStorage("videoQuality") var videoQuality = VideoQuality.auto.rawValue
    @AppStorage("maxBitrate") var maxBitrate = 120_000_000 // 120 Mbps for maximum quality
    @AppStorage("streamingMode") var streamingMode = StreamingMode.transcode.rawValue  // Force transcode to fix video decoder error -12900
    @AppStorage("videoCodec") var videoCodec = VideoCodec.h264.rawValue

    // MARK: - Audio Settings
    @AppStorage("audioQuality") var audioQuality = AudioQuality.high.rawValue
    @AppStorage("defaultAudioLanguage") var defaultAudioLanguage = "eng"

    // MARK: - Playback Settings
    @AppStorage("autoPlayNext") var autoPlayNext = true
    @AppStorage("autoPlayCountdown") var autoPlayCountdown = 10
    @AppStorage("resumeBehavior") var resumeBehavior = ResumeBehavior.alwaysAsk.rawValue
    @AppStorage("markPlayedThreshold") var markPlayedThreshold = 90
    @AppStorage("rememberAudioTrack") var rememberAudioTrack = true
    @AppStorage("rememberSubtitleTrack") var rememberSubtitleTrack = true

    // MARK: - Subtitle Settings
    @AppStorage("subtitleMode") var subtitleMode = SubtitleMode.off.rawValue
    @AppStorage("defaultSubtitleLanguage") var defaultSubtitleLanguage = "eng"
    @AppStorage("subtitleSize") var subtitleSize = SubtitleSize.medium.rawValue
    @AppStorage("subtitleFont") var subtitleFont = "System"
    @AppStorage("subtitleColor") var subtitleColor = "white"
    @AppStorage("subtitleBackground") var subtitleBackground = "semitransparent"
    @AppStorage("subtitleEdgeStyle") var subtitleEdgeStyle = "dropShadow"
    @AppStorage("subtitlePosition") var subtitlePosition = 0.9 // 0-1

    // MARK: - Skip Settings
    @AppStorage("autoSkipIntros") var autoSkipIntros = false
    @AppStorage("showSkipIntroButton") var showSkipIntroButton = true
    @AppStorage("skipIntroCountdown") var skipIntroCountdown = 5
    @AppStorage("autoSkipCredits") var autoSkipCredits = true
    @AppStorage("skipCreditsCountdown") var skipCreditsCountdown = 10
    @AppStorage("showNextEpisodeOverlay") var showNextEpisodeOverlay = true
    @AppStorage("autoSkipRecaps") var autoSkipRecaps = false
    @AppStorage("showSkipRecapButton") var showSkipRecapButton = true
    @AppStorage("skipBehavior") var skipBehavior = SkipBehavior.buttonWithDelay.rawValue

    // MARK: - Network Settings
    @AppStorage("preBufferDuration") var preBufferDuration = 10
    @AppStorage("cacheSize") var cacheSize = 500 // MB
    @AppStorage("lowBandwidthMode") var lowBandwidthMode = false
    @AppStorage("preferLocalNetwork") var preferLocalNetwork = true
    @AppStorage("allowTranscoding") var allowTranscoding = true

    // MARK: - Interface Settings
    @AppStorage("theme") var theme = AppTheme.dark.rawValue
    @AppStorage("accentColor") var accentColor = "667eea"
    @AppStorage("showRatings") var showRatings = true
    @AppStorage("showAdultContent") var showAdultContent = false
    @AppStorage("spoilerProtection") var spoilerProtection = false

    // MARK: - User Profile (for display only, actual user is in AuthService)
    @Published var currentUserName: String = ""
    @Published var currentUserImageURL: String?

    // MARK: - Computed Properties for Summaries

    var playbackSummary: String {
        let quality = VideoQuality(rawValue: videoQuality) ?? .auto
        return "\(quality.rawValue), \(autoPlayNext ? "Auto-play on" : "Auto-play off")"
    }

    var streamingSummary: String {
        let mbps = Double(maxBitrate) / 1_000_000
        return String(format: "Max %.1f Mbps", mbps)
    }

    var subtitleSummary: String {
        let lang = defaultSubtitleLanguage == "none" ? "Off" : defaultSubtitleLanguage.uppercased()
        return "Default: \(lang)"
    }

    var skipSummary: String {
        var enabled: [String] = []
        if autoSkipIntros { enabled.append("Intros") }
        if autoSkipCredits { enabled.append("Credits") }
        if autoSkipRecaps { enabled.append("Recaps") }

        return enabled.isEmpty ? "All disabled" : enabled.joined(separator: ", ")
    }

    // MARK: - Bitrate Helpers

    var bitrateDisplay: String {
        let mbps = Double(maxBitrate) / 1_000_000
        return String(format: "%.1f Mbps", mbps)
    }

    // MARK: - Methods

    func updateUserInfo(name: String, imageURL: String?) {
        self.currentUserName = name
        self.currentUserImageURL = imageURL
    }

    func resetToDefaults() {
        videoQuality = VideoQuality.auto.rawValue
        maxBitrate = 120_000_000  // 120 Mbps for maximum quality
        streamingMode = StreamingMode.transcode.rawValue  // Force transcode to fix video decoder error -12900
        audioQuality = AudioQuality.high.rawValue
        autoPlayNext = true
        autoPlayCountdown = 10
        subtitleMode = SubtitleMode.off.rawValue
        autoSkipIntros = false
        autoSkipCredits = true
        autoSkipRecaps = false
    }
}
