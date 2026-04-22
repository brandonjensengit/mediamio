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
            print("⚠️ configureSubtitles: No player or player item")
            return
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📝 SUBTITLE CONFIGURATION")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 MediaItem subtitle info:")
        print("   - Has subtitles: \(item.hasSubtitles)")
        print("   - Subtitle streams count: \(item.subtitleStreams.count)")

        guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            print("❌ AVPlayer: No legible media selection group found")
            print("❌ Jellyfin did NOT include subtitles in the HLS stream")
            return
        }

        print("✅ AVPlayer detected \(group.options.count) subtitle tracks")

        availableTracks = group.options.enumerated().map { index, option in
            print("   - Track \(index): \(option.displayName) (\(option.locale?.languageCode ?? "unknown"))")
            return SubtitleTrack(
                index: index,
                displayName: option.displayName,
                languageCode: option.locale?.languageCode ?? "unknown",
                option: option
            )
        }

        let mode = SubtitleMode(rawValue: settingsManager.subtitleMode) ?? .off
        print("📊 Subtitle mode setting: \(mode.rawValue)")
        print("📊 Default subtitle language: \(settingsManager.defaultSubtitleLanguage)")

        switch mode {
        case .off:
            // The original implementation also enabled the first track here,
            // commenting that the user can disable via native AVPlayer
            // controls. Preserved verbatim — Phase A is no behavior change.
            print("⚠️ Subtitle mode is OFF, but enabling first track anyway")
            if let firstOption = group.options.first {
                playerItem.select(firstOption, in: group)
                selectedIndex = 0
                print("✅ Enabled first subtitle: \(firstOption.displayName)")
            } else {
                playerItem.select(nil, in: group)
                selectedIndex = nil
            }

        case .on, .foreignOnly, .smart:
            let defaultLang = settingsManager.defaultSubtitleLanguage
            print("🔍 Looking for subtitle with language: \(defaultLang)")

            let match = group.options.enumerated().first { _, option in
                option.locale?.languageCode == defaultLang
            }

            if let (index, option) = match {
                playerItem.select(option, in: group)
                selectedIndex = index
                print("✅ Enabled matching subtitle: \(option.displayName) at index \(index)")
            } else if let firstOption = group.options.first {
                playerItem.select(firstOption, in: group)
                selectedIndex = 0
                print("⚠️ No language match, enabling first subtitle: \(firstOption.displayName)")
            } else {
                print("❌ No subtitles available to enable")
            }
        }
    }

    /// Programmatically pick a subtitle track. Pass `nil` to disable.
    func select(at index: Int?, player: AVPlayer?) {
        guard let player = player, let playerItem = player.currentItem else {
            print("⚠️ selectSubtitle: No player or player item")
            return
        }

        guard let group = playerItem.asset.mediaSelectionGroup(forMediaCharacteristic: .legible) else {
            print("⚠️ selectSubtitle: No legible media selection group")
            return
        }

        if let index = index, index >= 0 && index < group.options.count {
            let option = group.options[index]
            print("📝 Selecting subtitle at index \(index): \(option.displayName)")
            playerItem.select(option, in: group)
            selectedIndex = index
        } else {
            print("📝 Disabling subtitles (index=nil)")
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
