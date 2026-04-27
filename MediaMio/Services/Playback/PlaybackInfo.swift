//
//  PlaybackInfo.swift
//  MediaMio
//
//  Pure value type + builder that summarizes everything the "Playback
//  Info" panel needs to show (General / Video / Audio / Subtitle).
//  Never imports AVKit or SwiftUI — so the builder is trivially
//  unit-testable and the panel view controller stays a thin renderer.
//
//  The builder optionally consumes a `DeliveredStreamInfo` snapshot —
//  what AVPlayer is actually decoding, observed from
//  `AVPlayerItem.tracks` after `.readyToPlay`. When supplied, each
//  Video/Audio row carries both its source value and the delivered
//  value, and rows where the two disagree are flagged so the renderer
//  can highlight the mismatch in orange (matching the Jellyfin web
//  admin "Now Playing" panel layout). The "Play Method" badge in each
//  section header is computed from the observed match — *not* from
//  whatever mode the client requested — so a server that silently
//  transcodes can no longer hide behind a green Direct Play label.
//
//  When `delivered` is nil (e.g. the panel renders before AVPlayer
//  reaches readyToPlay), rows show source only and the badge falls back
//  to the requested mode.
//

import Foundation

/// One row of the info panel.
struct PlaybackInfoRow: Equatable {
    let label: String
    /// What the source file advertises for this attribute (always shown).
    let value: String
    /// What AVPlayer is actually decoding for this attribute. Nil when
    /// either we haven't observed the player yet or the row isn't a
    /// stream attribute (e.g. Container, File Size — those are file-level
    /// properties with no "delivered" counterpart).
    let delivered: String?

    init(label: String, value: String, delivered: String? = nil) {
        self.label = label
        self.value = value
        self.delivered = delivered
    }

    /// Source and Delivered disagree. Drives the orange-mismatch
    /// highlight in the cell renderer.
    var isMismatch: Bool {
        guard let delivered = delivered else { return false }
        return delivered.caseInsensitiveCompare(value) != .orderedSame
    }
}

/// Per-section badge shown next to the section title. Mirrors the
/// "Direct Play / Transcode" pill in Jellyfin's web Now Playing panel.
enum PlaybackBadge: String, Equatable {
    case directPlay = "Direct Play"
    case directStream = "Direct Stream"
    case remux = "Remux"
    case transcode = "Transcode"
}

/// Grouped rows under a section header.
struct PlaybackInfoSection: Equatable {
    let title: String
    let rows: [PlaybackInfoRow]
    /// When set, the renderer draws a green (directPlay/remux/directStream)
    /// or orange (transcode) pill next to the section title.
    let badge: PlaybackBadge?

    init(title: String, rows: [PlaybackInfoRow], badge: PlaybackBadge? = nil) {
        self.title = title
        self.rows = rows
        self.badge = badge
    }
}

/// Full info-panel payload — what the view controller renders.
struct PlaybackInfo: Equatable {
    let sections: [PlaybackInfoSection]

    /// Flattened row count; convenient for UITableView.
    var totalRows: Int { sections.reduce(0) { $0 + $1.rows.count } }
}

/// Snapshot of what AVPlayer is actually decoding, captured from
/// `AVPlayerItem.tracks[...].assetTrack.formatDescriptions` after the
/// item reaches `.readyToPlay`. Pure value type so the builder stays
/// AVKit-free and unit-testable.
struct DeliveredStreamInfo: Equatable {
    /// Codec FOURCC normalized to lowercase (e.g. "h264", "hevc",
    /// "aac", "ac-3", "ec-3").
    let videoCodec: String?
    let videoWidth: Int?
    let videoHeight: Int?
    /// "SDR", "HDR10", "HDR10+", "HLG", "DOVI", "DOVIWithHDR10" — same
    /// vocabulary as `MediaStream.videoRangeType` so direct comparison
    /// against source works without translation.
    let videoRange: String?
    /// HLS-variant indicated bitrate from `accessLog`. bps; nil when the
    /// access log hasn't populated yet.
    let videoBitrate: Int?
    let audioCodec: String?
    let audioChannels: Int?
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
    /// `delivered` is what AVPlayer is actually decoding. Pass nil
    /// before the player reaches readyToPlay or when the panel is
    /// being rendered without a live player (tests).
    static func build(
        item: MediaItem,
        mode: PlaybackMode,
        subtitleDisplay: String?,
        maxStreamingBitrate: Int? = nil,
        delivered: DeliveredStreamInfo? = nil
    ) -> PlaybackInfo {
        let source = item.mediaSources?.first
        let video = source?.mediaStreams?.first { $0.type == "Video" }
        let audio = source?.mediaStreams?.first { $0.type == "Audio" && ($0.isDefault ?? false) }
            ?? source?.mediaStreams?.first { $0.type == "Audio" }

        let videoSection = videoSection(video: video, delivered: delivered)
        let audioSection = audioSection(audio: audio, delivered: delivered)
        let general = generalSection(
            source: source,
            mode: mode,
            maxStreamingBitrate: maxStreamingBitrate,
            videoSection: videoSection,
            audioSection: audioSection,
            delivered: delivered,
            sourceContainer: source?.container
        )

        return PlaybackInfo(sections: [
            general,
            videoSection,
            audioSection,
            subtitleSection(subtitleDisplay: subtitleDisplay)
        ])
    }

    // MARK: - Sections

    private static func generalSection(
        source: MediaSource?,
        mode: PlaybackMode,
        maxStreamingBitrate: Int?,
        videoSection: PlaybackInfoSection,
        audioSection: PlaybackInfoSection,
        delivered: DeliveredStreamInfo?,
        sourceContainer: String?
    ) -> PlaybackInfoSection {
        // Compute the *observed* play method from per-row mismatches when
        // we have a delivered snapshot. Without one, fall back to the
        // requested mode so the panel still reads sensibly during the
        // pre-readyToPlay window.
        let observedMode = observedPlayMethod(
            requested: mode,
            videoSection: videoSection,
            audioSection: audioSection,
            delivered: delivered,
            sourceContainer: sourceContainer
        )

        var rows: [PlaybackInfoRow] = [
            PlaybackInfoRow(label: "Play Method", value: observedMode.rawValue)
        ]
        // When the requested mode disagrees with what's actually being
        // delivered, surface the requested side as a separate row. This
        // is the diagnostic that exposes a server-side override (e.g.
        // client asked for Remux, server force-transcoded to H.264 1080p
        // because no DeviceProfile was sent).
        if delivered != nil && observedMode != mode {
            rows.append(PlaybackInfoRow(
                label: "Requested Mode",
                value: mode.rawValue
            ))
        }
        if let container = source?.container, !container.isEmpty {
            rows.append(PlaybackInfoRow(label: "Container", value: container.uppercased()))
        }
        if let size = source?.size {
            rows.append(PlaybackInfoRow(label: "File Size", value: formatFileSize(bytes: size)))
        }
        if let total = totalBitrate(source: source) {
            rows.append(PlaybackInfoRow(label: "Total Bitrate", value: formatBitrate(bps: total)))
        }
        if let cap = maxStreamingBitrate {
            rows.append(PlaybackInfoRow(label: "Max Bitrate", value: formatBitrate(bps: cap)))
        }
        return PlaybackInfoSection(
            title: "General",
            rows: rows,
            badge: PlaybackBadge(rawValue: observedMode.rawValue)
        )
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

    private static func videoSection(
        video: MediaStream?,
        delivered: DeliveredStreamInfo?
    ) -> PlaybackInfoSection {
        guard let video = video else {
            return PlaybackInfoSection(title: "Video", rows: [
                PlaybackInfoRow(label: "Video", value: "Unknown")
            ])
        }
        var rows: [PlaybackInfoRow] = []
        if let codec = video.codec, !codec.isEmpty {
            let deliveredCodec = delivered?.videoCodec.map { normalizeCodec($0).uppercased() }
            rows.append(PlaybackInfoRow(
                label: "Codec",
                value: codec.uppercased(),
                delivered: deliveredCodec
            ))
        }
        if let profile = video.profile, !profile.isEmpty {
            // Profile is source-only — AVPlayer's track formatDescription
            // doesn't expose a comparable "Main 10 / High" string the way
            // Jellyfin's MediaStream does, so leave the delivered side
            // empty rather than fake a mismatch.
            rows.append(PlaybackInfoRow(label: "Profile", value: profile))
        }
        if let width = video.width, let height = video.height {
            let deliveredResolution: String? = {
                guard let dw = delivered?.videoWidth, let dh = delivered?.videoHeight else { return nil }
                return "\(dw) × \(dh)"
            }()
            rows.append(PlaybackInfoRow(
                label: "Resolution",
                value: "\(width) × \(height)",
                delivered: deliveredResolution
            ))
        }
        if let bitrate = video.bitRate {
            let deliveredBitrate = delivered?.videoBitrate.map { formatBitrate(bps: $0) }
            rows.append(PlaybackInfoRow(
                label: "Bitrate",
                value: formatBitrate(bps: bitrate),
                delivered: deliveredBitrate
            ))
        }
        if let range = formatVideoRange(video) {
            rows.append(PlaybackInfoRow(
                label: "Range",
                value: range,
                delivered: delivered?.videoRange
            ))
        }
        return PlaybackInfoSection(
            title: "Video",
            rows: rows,
            badge: badge(for: rows, defaulting: delivered == nil ? nil : .directPlay)
        )
    }

    private static func audioSection(
        audio: MediaStream?,
        delivered: DeliveredStreamInfo?
    ) -> PlaybackInfoSection {
        guard let audio = audio else {
            return PlaybackInfoSection(title: "Audio", rows: [
                PlaybackInfoRow(label: "Audio", value: "Unknown")
            ])
        }
        var rows: [PlaybackInfoRow] = []
        if let codec = audio.codec, !codec.isEmpty {
            let deliveredCodec = delivered?.audioCodec.map { normalizeCodec($0).uppercased() }
            rows.append(PlaybackInfoRow(
                label: "Codec",
                value: codec.uppercased(),
                delivered: deliveredCodec
            ))
        }
        if let channelLabel = formatChannels(audio) {
            let deliveredChannels = delivered?.audioChannels.map { formatChannelCount($0) }
            rows.append(PlaybackInfoRow(
                label: "Channels",
                value: channelLabel,
                delivered: deliveredChannels
            ))
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
        return PlaybackInfoSection(
            title: "Audio",
            rows: rows,
            badge: badge(for: rows, defaulting: delivered == nil ? nil : .directPlay)
        )
    }

    private static func subtitleSection(subtitleDisplay: String?) -> PlaybackInfoSection {
        return PlaybackInfoSection(title: "Subtitle", rows: [
            PlaybackInfoRow(label: "Track", value: subtitleDisplay ?? "Off")
        ])
    }

    // MARK: - Observed-mode logic

    /// Compute the play method actually being delivered by comparing each
    /// stream attribute Source vs Delivered. The four combinations map
    /// onto the same vocabulary the URL builder uses for *requesting*:
    ///
    ///   - all match + container supported  → Direct Play
    ///   - all match + container NOT supported → Remux
    ///   - video matches, audio differs     → Direct Stream
    ///   - video differs                    → Transcode
    ///
    /// Falls back to `requested` when no delivered snapshot is available
    /// (the panel is rendering before readyToPlay, or in tests).
    private static func observedPlayMethod(
        requested: PlaybackMode,
        videoSection: PlaybackInfoSection,
        audioSection: PlaybackInfoSection,
        delivered: DeliveredStreamInfo?,
        sourceContainer: String?
    ) -> PlaybackMode {
        guard delivered != nil else { return requested }

        let videoMatch = !videoSection.rows.contains { $0.isMismatch }
        let audioMatch = !audioSection.rows.contains { $0.isMismatch }

        // We approximate "container delivered" by whether the source
        // container is one Apple TV can natively demux. HLS always wraps
        // segments in mp4 or ts, so the source container is what the
        // user cares about — "did the server change the wrapper?"
        let containerSupported = AppleTVCodecSupport.shared.isContainerSupported(sourceContainer)

        switch (videoMatch, audioMatch, containerSupported) {
        case (true, true, true):   return .directPlay
        case (true, true, false):  return .remux
        case (true, false, _):     return .directStream
        default:                   return .transcode
        }
    }

    /// Pick the per-section badge from the rows in that section.
    /// `defaulting` is what we render when there's no source/delivered
    /// disagreement *and* a delivered snapshot exists — i.e. the optimistic
    /// "Direct Play" green pill. With no delivered snapshot, return nil so
    /// the section header is unbadged.
    private static func badge(
        for rows: [PlaybackInfoRow],
        defaulting: PlaybackBadge?
    ) -> PlaybackBadge? {
        let anyMismatch = rows.contains { $0.isMismatch }
        if anyMismatch { return .transcode }
        return defaulting
    }

    // MARK: - Formatting

    /// `18500000` → "18.5 Mbps", `640000` → "640 kbps". Floor for readability.
    static func formatBitrate(bps: Int) -> String {
        if bps >= 1_000_000 {
            let mbps = Double(bps) / 1_000_000
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
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / 1_048_576
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
            default: return type
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
            return layout.capitalized
        }
        if let count = stream.channels {
            return formatChannelCount(count)
        }
        return nil
    }

    static func formatChannelCount(_ count: Int) -> String {
        switch count {
        case 1: return "Mono"
        case 2: return "Stereo"
        case 6: return "5.1"
        case 8: return "7.1"
        default: return "\(count) ch"
        }
    }

    /// Map AVFoundation FourCC strings into the same vocabulary
    /// `MediaStream.codec` uses, so direct string equality works
    /// downstream. AVFoundation hands back codes like "avc1" / "hvc1" /
    /// "ac-3" / "ec-3"; Jellyfin reports "h264" / "hevc" / "ac3" / "eac3".
    static func normalizeCodec(_ code: String) -> String {
        switch code.lowercased() {
        case "avc1", "avc", "h264": return "h264"
        case "hvc1", "hev1", "hevc", "h265": return "hevc"
        case "vp09", "vp9": return "vp9"
        case "mp4a", "aac": return "aac"
        case "ac-3", "ac3": return "ac3"
        case "ec-3", "eac3": return "eac3"
        default: return code.lowercased()
        }
    }
}
