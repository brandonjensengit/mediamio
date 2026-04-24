//
//  PlaybackInfo.swift
//  MediaMio
//
//  Pure value type + builder that summarizes everything the "Playback
//  Info" panel needs to show (General / Video / Audio / Subtitle).
//  Never imports AVKit or SwiftUI — so the builder is trivially
//  unit-testable and the panel view controller stays a thin renderer.
//  Constraint: the builder operates on MediaItem + PlaybackMode alone.
//  Runtime-observed fields (AVPlayerItem.tracks) are intentionally NOT
//  a dependency — Jellyfin's MediaSource already tells us what's in the
//  file, and showing what the server advertised is the right default.
//

import Foundation

/// One row of the info panel.
struct PlaybackInfoRow: Equatable {
    let label: String
    let value: String
}

/// Grouped rows under a section header.
struct PlaybackInfoSection: Equatable {
    let title: String
    let rows: [PlaybackInfoRow]
}

/// Full info-panel payload — what the view controller renders.
struct PlaybackInfo: Equatable {
    let sections: [PlaybackInfoSection]

    /// Flattened row count; convenient for UITableView.
    var totalRows: Int { sections.reduce(0) { $0 + $1.rows.count } }
}

// MARK: - Builder

enum PlaybackInfoBuilder {

    /// Build a full info payload. `subtitleDisplay` is the label shown for
    /// the currently-selected subtitle track, or nil when subtitles are
    /// off. Caller (typically `SubtitleTrackManager`) owns that decision.
    /// `maxStreamingBitrate` is the user's configured cap in bps (from
    /// SettingsManager); when provided, it's surfaced in the General
    /// section so users can see *their cap* alongside the *source
    /// bitrate* and understand why a 5 Mbps file doesn't get throttled
    /// by a 120 Mbps cap.
    static func build(
        item: MediaItem,
        mode: PlaybackMode,
        subtitleDisplay: String?,
        maxStreamingBitrate: Int? = nil
    ) -> PlaybackInfo {
        let source = item.mediaSources?.first
        let video = source?.mediaStreams?.first { $0.type == "Video" }
        let audio = source?.mediaStreams?.first { $0.type == "Audio" && ($0.isDefault ?? false) }
            ?? source?.mediaStreams?.first { $0.type == "Audio" }

        return PlaybackInfo(sections: [
            generalSection(source: source, mode: mode, maxStreamingBitrate: maxStreamingBitrate),
            videoSection(video: video),
            audioSection(audio: audio),
            subtitleSection(subtitleDisplay: subtitleDisplay)
        ])
    }

    // MARK: - Sections

    private static func generalSection(
        source: MediaSource?,
        mode: PlaybackMode,
        maxStreamingBitrate: Int?
    ) -> PlaybackInfoSection {
        var rows: [PlaybackInfoRow] = [
            PlaybackInfoRow(label: "Play Method", value: mode.rawValue)
        ]
        if let container = source?.container, !container.isEmpty {
            rows.append(PlaybackInfoRow(label: "Container", value: container.uppercased()))
        }
        if let size = source?.size {
            rows.append(PlaybackInfoRow(label: "File Size", value: formatFileSize(bytes: size)))
        }
        if let total = totalBitrate(source: source) {
            rows.append(PlaybackInfoRow(label: "Total Bitrate", value: formatBitrate(bps: total)))
        }
        // Placed right after Total Bitrate so the file's natural rate and
        // the user's cap read as a pair. Makes it obvious why a 5 Mbps
        // file under a 120 Mbps cap isn't being throttled.
        if let cap = maxStreamingBitrate {
            rows.append(PlaybackInfoRow(label: "Max Bitrate", value: formatBitrate(bps: cap)))
        }
        return PlaybackInfoSection(title: "General", rows: rows)
    }

    /// Total bitrate for the General section. Prefer the sum of the
    /// per-stream bitrates — Jellyfin's `MediaSource.Bitrate` is unreliable
    /// for MKV remuxes (it sometimes reports just the video stream's
    /// bitrate, so a 50 Mbps video + 640 kbps audio reads as "50 Mbps"
    /// instead of "50.6 Mbps"; and for a subset of scanned files it
    /// reports only the primary stream, giving wildly-low totals like
    /// "16 Mbps" on an actual 50 Mbps file). Falling back to the source
    /// field only when every stream is missing its bitrate keeps us
    /// correct on the common case without regressing when streams don't
    /// report their own rate.
    static func totalBitrate(source: MediaSource?) -> Int? {
        guard let source = source else { return nil }
        let streamSum = (source.mediaStreams ?? [])
            .compactMap { $0.bitRate }
            .reduce(0, +)
        if streamSum > 0 { return streamSum }
        return source.bitrate
    }

    private static func videoSection(video: MediaStream?) -> PlaybackInfoSection {
        guard let video = video else {
            return PlaybackInfoSection(title: "Video", rows: [
                PlaybackInfoRow(label: "Video", value: "Unknown")
            ])
        }
        var rows: [PlaybackInfoRow] = []
        if let codec = video.codec, !codec.isEmpty {
            rows.append(PlaybackInfoRow(label: "Codec", value: codec.uppercased()))
        }
        if let profile = video.profile, !profile.isEmpty {
            rows.append(PlaybackInfoRow(label: "Profile", value: profile))
        }
        if let width = video.width, let height = video.height {
            rows.append(PlaybackInfoRow(label: "Resolution", value: "\(width) × \(height)"))
        }
        if let bitrate = video.bitRate {
            rows.append(PlaybackInfoRow(label: "Bitrate", value: formatBitrate(bps: bitrate)))
        }
        if let range = formatVideoRange(video) {
            rows.append(PlaybackInfoRow(label: "Range", value: range))
        }
        return PlaybackInfoSection(title: "Video", rows: rows)
    }

    private static func audioSection(audio: MediaStream?) -> PlaybackInfoSection {
        guard let audio = audio else {
            return PlaybackInfoSection(title: "Audio", rows: [
                PlaybackInfoRow(label: "Audio", value: "Unknown")
            ])
        }
        var rows: [PlaybackInfoRow] = []
        if let codec = audio.codec, !codec.isEmpty {
            rows.append(PlaybackInfoRow(label: "Codec", value: codec.uppercased()))
        }
        if let channelLabel = formatChannels(audio) {
            rows.append(PlaybackInfoRow(label: "Channels", value: channelLabel))
        }
        if let bitrate = audio.bitRate {
            rows.append(PlaybackInfoRow(label: "Bitrate", value: formatBitrate(bps: bitrate)))
        }
        if let rate = audio.sampleRate {
            rows.append(PlaybackInfoRow(label: "Sample Rate", value: "\(rate / 1000) kHz"))
        }
        if let lang = audio.language, !lang.isEmpty {
            rows.append(PlaybackInfoRow(label: "Language", value: lang.uppercased()))
        }
        return PlaybackInfoSection(title: "Audio", rows: rows)
    }

    private static func subtitleSection(subtitleDisplay: String?) -> PlaybackInfoSection {
        return PlaybackInfoSection(title: "Subtitle", rows: [
            PlaybackInfoRow(label: "Track", value: subtitleDisplay ?? "Off")
        ])
    }

    // MARK: - Formatting

    /// `18500000` → "18.5 Mbps", `640000` → "640 kbps". Floor for readability.
    static func formatBitrate(bps: Int) -> String {
        if bps >= 1_000_000 {
            let mbps = Double(bps) / 1_000_000
            // One decimal for anything under 10, whole number above.
            return mbps < 10 ? String(format: "%.1f Mbps", mbps) : "\(Int(mbps.rounded())) Mbps"
        } else if bps >= 1_000 {
            return "\(bps / 1_000) kbps"
        } else {
            return "\(bps) bps"
        }
    }

    /// `4_200_000_000` → "3.9 GB". Binary (GiB) not decimal — matches what
    /// users see in Finder / Jellyfin's own UI.
    static func formatFileSize(bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824  // 1024³
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576      // 1024²
        return String(format: "%.0f MB", mb)
    }

    /// Prefer `VideoRangeType` (newer, more specific). Fall back to the
    /// legacy `VideoRange` (SDR/HDR) field on older Jellyfin installs.
    /// Return nil if neither is set so the row is hidden rather than
    /// shown as "Unknown".
    static func formatVideoRange(_ stream: MediaStream) -> String? {
        if let type = stream.videoRangeType, !type.isEmpty {
            switch type {
            case "SDR": return "SDR"
            case "HDR10": return "HDR10"
            case "HDR10Plus": return "HDR10+"
            case "DOVI": return "Dolby Vision"
            case "DOVIWithHDR10": return "Dolby Vision + HDR10"
            case "HLG": return "HLG"
            default: return type  // unknown tag — surface the raw value
            }
        }
        if let range = stream.videoRange, !range.isEmpty {
            return range.uppercased()
        }
        return nil
    }

    /// Prefer Jellyfin's pre-formatted `ChannelLayout` ("5.1", "7.1",
    /// "stereo") — it's what the server itself displays. Fall back to a
    /// raw channel count when layout isn't set.
    static func formatChannels(_ stream: MediaStream) -> String? {
        if let layout = stream.channelLayout, !layout.isEmpty {
            return layout.capitalized  // "stereo" → "Stereo", "5.1" → "5.1"
        }
        if let count = stream.channels {
            switch count {
            case 1: return "Mono"
            case 2: return "Stereo"
            case 6: return "5.1"
            case 8: return "7.1"
            default: return "\(count) ch"
            }
        }
        return nil
    }
}
