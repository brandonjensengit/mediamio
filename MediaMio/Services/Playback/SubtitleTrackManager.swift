//
//  SubtitleTrackManager.swift
//  MediaMio
//
//  Phase A refactor: extracted from VideoPlayerViewModel (lines 929–1099 of
//  the original). Wraps `AVMediaSelectionGroup` for the legible (subtitle)
//  characteristic — enumerates available tracks, picks an initial selection
//  based on user settings, and exposes a setter so the UI can toggle tracks.
//
//  Constraint: only touches AVKit + the user's subtitle settings. No HTTP,
//  no Jellyfin reporting.
//

import AVFoundation
import Combine
import Foundation

/// A subtitle track available on the current `AVPlayerItem`.
struct SubtitleTrack: Identifiable {
    let index: Int
    let displayName: String
    let languageCode: String
    let option: AVMediaSelectionOption

    var id: Int { index }
}

/// Owns the AVPlayer subtitle selection group. Both `availableTracks` and
/// `selectedIndex` are `@Published` so the player UI can bind to them.
@MainActor
final class SubtitleTrackManager: ObservableObject {
    @Published private(set) var availableTracks: [SubtitleTrack] = []
    @Published private(set) var selectedIndex: Int? = nil

    private let item: MediaItem
    private let settingsManager: SettingsManager

    init(item: MediaItem, settingsManager: SettingsManager) {
        self.item = item
        self.settingsManager = settingsManager
    }

    /// Read available subtitle tracks from the player item, then select one
    /// based on the user's `subtitleMode` and `defaultSubtitleLanguage`.
    func configure(player: AVPlayer?) {
        guard let player = player, let playerItem = player.currentItem else {
            DebugLog.playback("⚠️ configureSubtitles: No player or player item")
            return
        }

        DebugLog.playback("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        DebugLog.playback("📝 SUBTITLE CONFIGURATION")
        DebugLog.playback("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        DebugLog.playback("📊 MediaItem subtitle info:")
        DebugLog.playback("   - Has subtitles: \(item.hasSubtitles)")
        DebugLog.playback("   - Subtitle streams count: \(item.subtitleStreams.count)")

        guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            DebugLog.playback("❌ AVPlayer: No legible media selection group found")
            DebugLog.playback("❌ Jellyfin did NOT include subtitles in the HLS stream")
            return
        }

        DebugLog.playback("✅ AVPlayer detected \(group.options.count) subtitle tracks")

        availableTracks = group.options.enumerated().map { index, option in
            DebugLog.playback("   - Track \(index): \(option.displayName) (\(option.locale?.languageCode ?? "unknown"))")
            return SubtitleTrack(
                index: index,
                displayName: option.displayName,
                languageCode: option.locale?.languageCode ?? "unknown",
                option: option
            )
        }

        let mode = SubtitleMode(rawValue: settingsManager.subtitleMode) ?? .off
        DebugLog.playback("📊 Subtitle mode setting: \(mode.rawValue)")
        DebugLog.playback("📊 Default subtitle language: \(settingsManager.defaultSubtitleLanguage)")

        switch mode {
        case .off:
            // Subtitles off means off. (The original force-enabled the first
            // track here, which turned on a random language unasked.)
            playerItem.select(nil, in: group)
            selectedIndex = nil
            DebugLog.playback("📝 Subtitle mode OFF — no track selected")

        case .on, .foreignOnly, .smart:
            let defaultLang = settingsManager.defaultSubtitleLanguage
            DebugLog.playback("🔍 Looking for subtitle with language: \(defaultLang)")

            let match = group.options.enumerated().first { _, option in
                option.locale?.languageCode == defaultLang
            }

            if let (index, option) = match {
                playerItem.select(option, in: group)
                selectedIndex = index
                DebugLog.playback("✅ Enabled matching subtitle: \(option.displayName) at index \(index)")
            } else {
                // Preferred language unavailable — leave subtitles off rather
                // than forcing an arbitrary foreign track (e.g. Vietnamese on
                // an English request). User can pick one from the track list.
                playerItem.select(nil, in: group)
                selectedIndex = nil
                DebugLog.playback("ℹ️ No \(defaultLang) subtitle among \(group.options.count) tracks — leaving off")
            }
        }
    }

    /// Programmatically pick a subtitle track. Pass `nil` to disable.
    func select(at index: Int?, player: AVPlayer?) {
        guard let player = player, let playerItem = player.currentItem else {
            DebugLog.playback("⚠️ selectSubtitle: No player or player item")
            return
        }

        guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            DebugLog.playback("⚠️ selectSubtitle: No legible media selection group")
            return
        }

        if let index = index, index >= 0 && index < group.options.count {
            let option = group.options[index]
            DebugLog.playback("📝 Selecting subtitle at index \(index): \(option.displayName)")
            playerItem.select(option, in: group)
            selectedIndex = index
        } else {
            DebugLog.playback("📝 Disabling subtitles (index=nil)")
            playerItem.select(nil, in: group)
            selectedIndex = nil
        }
    }

    var currentName: String {
        if let index = selectedIndex, index < availableTracks.count {
            return availableTracks[index].displayName
        }
        return "Off"
    }
}
