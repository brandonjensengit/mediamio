//
//  PlaybackInfoBuilderTests.swift
//  MediaMioTests
//
//  Contract tests for the Playback Info panel's data builder. The builder
//  has to be tolerant of the wildly varying completeness of Jellyfin
//  MediaStream payloads (old servers omit VideoRangeType; transcoded
//  streams omit channels; some sources have no MediaSources at all).
//  These tests pin:
//   - play-method labels (one per PlaybackMode)
//   - bitrate formatting (bps → Mbps / kbps, the tricky < 10 Mbps case)
//   - file size formatting (bytes → GB / MB)
//   - HDR range mapping (VideoRangeType preferred, falls back to VideoRange)
//   - channel formatting (ChannelLayout preferred, falls back to count)
//   - graceful degradation when fields are nil
//

import Testing
@testable import MediaMio

struct PlaybackInfoBuilderTests {

    // MARK: - Bitrate formatting

    @Test("bitrate: under 1 Mbps formats as kbps")
    func bitrateKilobits() {
        #expect(PlaybackInfoBuilder.formatBitrate(bps: 640_000) == "640 kbps")
        #expect(PlaybackInfoBuilder.formatBitrate(bps: 192_000) == "192 kbps")
    }

    @Test("bitrate: under 10 Mbps gets one decimal")
    func bitrateMegabitsSmall() {
        #expect(PlaybackInfoBuilder.formatBitrate(bps: 5_000_000) == "5.0 Mbps")
        #expect(PlaybackInfoBuilder.formatBitrate(bps: 8_500_000) == "8.5 Mbps")
    }

    @Test("bitrate: at or above 10 Mbps rounds to whole number")
    func bitrateMegabitsLarge() {
        #expect(PlaybackInfoBuilder.formatBitrate(bps: 18_500_000) == "19 Mbps")
        #expect(PlaybackInfoBuilder.formatBitrate(bps: 50_000_000) == "50 Mbps")
    }

    @Test("bitrate: sub-kbps edge case falls through to bps")
    func bitrateSubKilobit() {
        #expect(PlaybackInfoBuilder.formatBitrate(bps: 500) == "500 bps")
    }

    // MARK: - File size formatting

    @Test("fileSize: GB range uses one decimal")
    func fileSizeGigabytes() {
        // 4.2 GiB
        let bytes: Int64 = 4_509_715_660
        #expect(PlaybackInfoBuilder.formatFileSize(bytes: bytes) == "4.2 GB")
    }

    @Test("fileSize: sub-GB switches to MB")
    func fileSizeMegabytes() {
        // 700 MiB
        let bytes: Int64 = 700 * 1_048_576
        #expect(PlaybackInfoBuilder.formatFileSize(bytes: bytes) == "700 MB")
    }

    // MARK: - Video range mapping

    @Test("videoRange: VideoRangeType is preferred over legacy VideoRange")
    func videoRangeTypeWins() {
        let stream = makeStream(videoRange: "HDR", videoRangeType: "HDR10")
        #expect(PlaybackInfoBuilder.formatVideoRange(stream) == "HDR10")
    }

    @Test("videoRange: known VideoRangeType tags get friendly labels")
    func videoRangeTypeFriendly() {
        #expect(PlaybackInfoBuilder.formatVideoRange(makeStream(videoRangeType: "SDR")) == "SDR")
        #expect(PlaybackInfoBuilder.formatVideoRange(makeStream(videoRangeType: "HDR10Plus")) == "HDR10+")
        #expect(PlaybackInfoBuilder.formatVideoRange(makeStream(videoRangeType: "DOVI")) == "Dolby Vision")
        #expect(PlaybackInfoBuilder.formatVideoRange(makeStream(videoRangeType: "DOVIWithHDR10")) == "Dolby Vision + HDR10")
        #expect(PlaybackInfoBuilder.formatVideoRange(makeStream(videoRangeType: "HLG")) == "HLG")
    }

    @Test("videoRange: unknown VideoRangeType surfaces the raw value")
    func videoRangeTypeUnknown() {
        #expect(PlaybackInfoBuilder.formatVideoRange(makeStream(videoRangeType: "FutureFormat")) == "FutureFormat")
    }

    @Test("videoRange: legacy VideoRange field alone is upper-cased")
    func videoRangeLegacyFallback() {
        #expect(PlaybackInfoBuilder.formatVideoRange(makeStream(videoRange: "hdr")) == "HDR")
        #expect(PlaybackInfoBuilder.formatVideoRange(makeStream(videoRange: "sdr")) == "SDR")
    }

    @Test("videoRange: nil when neither field is set")
    func videoRangeAbsent() {
        #expect(PlaybackInfoBuilder.formatVideoRange(makeStream()) == nil)
    }

    // MARK: - Channel formatting

    @Test("channels: ChannelLayout takes precedence and is capitalized")
    func channelsLayoutWins() {
        let stream = makeStream(channels: 2, channelLayout: "stereo")
        #expect(PlaybackInfoBuilder.formatChannels(stream) == "Stereo")
    }

    @Test("channels: 5.1 layout stays numeric (capitalizing has no effect)")
    func channelsSurround() {
        let stream = makeStream(channels: 6, channelLayout: "5.1")
        #expect(PlaybackInfoBuilder.formatChannels(stream) == "5.1")
    }

    @Test("channels: count-only falls back to friendly labels")
    func channelsFromCount() {
        #expect(PlaybackInfoBuilder.formatChannels(makeStream(channels: 1)) == "Mono")
        #expect(PlaybackInfoBuilder.formatChannels(makeStream(channels: 2)) == "Stereo")
        #expect(PlaybackInfoBuilder.formatChannels(makeStream(channels: 6)) == "5.1")
        #expect(PlaybackInfoBuilder.formatChannels(makeStream(channels: 8)) == "7.1")
    }

    @Test("channels: exotic counts format with ' ch' suffix")
    func channelsExoticCount() {
        #expect(PlaybackInfoBuilder.formatChannels(makeStream(channels: 4)) == "4 ch")
    }

    @Test("channels: nil when neither is set")
    func channelsAbsent() {
        #expect(PlaybackInfoBuilder.formatChannels(makeStream()) == nil)
    }

    // MARK: - Full-payload build

    @Test("build: each PlaybackMode shows its friendly label in General")
    func buildShowsEveryPlayMethod() {
        for mode in [PlaybackMode.directPlay, .directStream, .remux, .transcode] {
            let item = makeItem()
            let info = PlaybackInfoBuilder.build(item: item, mode: mode, subtitleDisplay: nil)
            let generalRows = info.sections.first { $0.title == "General" }?.rows
            let method = generalRows?.first { $0.label == "Play Method" }?.value
            #expect(method == mode.rawValue)
        }
    }

    @Test("build: has four sections in canonical order")
    func buildHasFourSections() {
        let info = PlaybackInfoBuilder.build(item: makeItem(), mode: .directPlay, subtitleDisplay: nil)
        #expect(info.sections.map { $0.title } == ["General", "Video", "Audio", "Subtitle"])
    }

    @Test("build: absent subtitle shows 'Off'")
    func buildSubtitleOff() {
        let info = PlaybackInfoBuilder.build(item: makeItem(), mode: .directPlay, subtitleDisplay: nil)
        let sub = info.sections.first { $0.title == "Subtitle" }?.rows.first
        #expect(sub?.value == "Off")
    }

    @Test("build: present subtitle shows its display name")
    func buildSubtitleOn() {
        let info = PlaybackInfoBuilder.build(
            item: makeItem(), mode: .directPlay, subtitleDisplay: "English (SDH)"
        )
        let sub = info.sections.first { $0.title == "Subtitle" }?.rows.first
        #expect(sub?.value == "English (SDH)")
    }

    @Test("build: item with no MediaSources still produces all four sections")
    func buildNoMediaSources() {
        // Real case: an item that was decoded from a list endpoint that
        // doesn't include MediaSources. The pane must not crash — it
        // should show "Unknown" placeholders instead of hiding sections
        // (so the user can tell the data is missing, not the app is bad).
        let item = makeItem(withMediaSources: false)
        let info = PlaybackInfoBuilder.build(item: item, mode: .transcode, subtitleDisplay: nil)
        #expect(info.sections.count == 4)
        #expect(info.sections[1].rows.contains { $0.value == "Unknown" })  // Video
        #expect(info.sections[2].rows.contains { $0.value == "Unknown" })  // Audio
    }

    @Test("build: Max Bitrate row appears in General when maxStreamingBitrate is provided")
    func buildShowsMaxBitrateRow() {
        let info = PlaybackInfoBuilder.build(
            item: makeItem(),
            mode: .directPlay,
            subtitleDisplay: nil,
            maxStreamingBitrate: 120_000_000
        )
        let general = info.sections.first { $0.title == "General" }
        let maxRow = general?.rows.first { $0.label == "Max Bitrate" }
        #expect(maxRow?.value == "120 Mbps")
    }

    @Test("build: Max Bitrate row is omitted when maxStreamingBitrate is nil")
    func buildOmitsMaxBitrateRowWhenNil() {
        let info = PlaybackInfoBuilder.build(
            item: makeItem(),
            mode: .directPlay,
            subtitleDisplay: nil
        )
        let general = info.sections.first { $0.title == "General" }
        #expect(general?.rows.contains { $0.label == "Max Bitrate" } == false)
    }

    // MARK: - Total bitrate (the reason Brandon flagged this)

    @Test("totalBitrate: sums per-stream bitrates (video + audio)")
    func totalBitrateSumsStreams() {
        // 50 Mbps video + 640 kbps audio = 50,640,000 bps total
        let source = MediaSource(
            id: "s1", name: nil, size: nil, container: nil,
            bitrate: 16_000_000,   // the "wrong" MediaSource.Bitrate Jellyfin sometimes reports
            mediaStreams: [
                MediaStream(
                    index: 0, type: "Video", codec: "hevc", profile: nil,
                    width: 3840, height: 2160, bitRate: 50_000_000,
                    language: nil, displayTitle: nil, title: nil,
                    isExternal: nil, isDefault: true,
                    channels: nil, channelLayout: nil, sampleRate: nil,
                    videoRange: nil, videoRangeType: nil
                ),
                MediaStream(
                    index: 1, type: "Audio", codec: "eac3", profile: nil,
                    width: nil, height: nil, bitRate: 640_000,
                    language: "eng", displayTitle: nil, title: nil,
                    isExternal: nil, isDefault: true,
                    channels: 6, channelLayout: "5.1", sampleRate: nil,
                    videoRange: nil, videoRangeType: nil
                )
            ]
        )
        #expect(PlaybackInfoBuilder.totalBitrate(source: source) == 50_640_000)
    }

    @Test("totalBitrate: falls back to MediaSource.Bitrate when streams have no bitrate")
    func totalBitrateFallsBack() {
        let source = MediaSource(
            id: "s1", name: nil, size: nil, container: nil,
            bitrate: 20_000_000,
            mediaStreams: [
                MediaStream(
                    index: 0, type: "Video", codec: "h264", profile: nil,
                    width: nil, height: nil, bitRate: nil,
                    language: nil, displayTitle: nil, title: nil,
                    isExternal: nil, isDefault: true,
                    channels: nil, channelLayout: nil, sampleRate: nil,
                    videoRange: nil, videoRangeType: nil
                )
            ]
        )
        #expect(PlaybackInfoBuilder.totalBitrate(source: source) == 20_000_000)
    }

    @Test("totalBitrate: nil when both sources of truth are missing")
    func totalBitrateUnknown() {
        let source = MediaSource(
            id: "s1", name: nil, size: nil, container: nil,
            bitrate: nil, mediaStreams: nil
        )
        #expect(PlaybackInfoBuilder.totalBitrate(source: source) == nil)
    }

    // MARK: - Source vs Delivered (the core diagnostic the panel surfaces)

    @Test("delivered nil: rows have no delivered companion and section badge is unset")
    func deliveredAbsentLeavesRowsClean() {
        let info = PlaybackInfoBuilder.build(
            item: makeFullItem(),
            mode: .remux,
            subtitleDisplay: nil,
            delivered: nil
        )
        let video = info.sections.first { $0.title == "Video" }
        let codecRow = video?.rows.first { $0.label == "Codec" }
        #expect(codecRow?.delivered == nil)
        #expect(codecRow?.isMismatch == false)
        // No delivered snapshot ⇒ no badge (panel falls back to source-only rendering).
        #expect(video?.badge == nil)
    }

    @Test("delivered matches source: video rows render Direct Play badge, no mismatch flags")
    func deliveredMatchesSourceShowsDirectPlay() {
        // mp4 container is in AppleTVCodecSupport.supportedContainers, so
        // an all-match snapshot ⇒ Direct Play.
        let mp4Item = makeFullItem(container: "mp4")
        let delivered = DeliveredStreamInfo(
            videoCodec: "hvc1",            // FourCC; normalises to "hevc"
            videoWidth: 3840, videoHeight: 2160,
            videoRange: "HDR10",           // doesn't match source DOVI — but the
            videoBitrate: nil,             // realistic case is HDR10 source for
            audioCodec: "ec-3",            // this matching test
            audioChannels: 6
        )
        let _ = delivered  // silence unused if compiler warns
        // Build a source whose range matches HDR10 so we can assert match.
        let info = PlaybackInfoBuilder.build(
            item: makeFullItem(container: "mp4", videoRangeType: "HDR10"),
            mode: .directPlay,
            subtitleDisplay: nil,
            delivered: DeliveredStreamInfo(
                videoCodec: "hvc1",
                videoWidth: 3840, videoHeight: 2160,
                videoRange: "HDR10",
                videoBitrate: nil,
                audioCodec: "ec-3",
                audioChannels: 6
            )
        )
        let general = info.sections.first { $0.title == "General" }
        #expect(general?.rows.first(where: { $0.label == "Play Method" })?.value == "Direct Play")
        #expect(general?.badge == .directPlay)
        // No "Requested Mode" row should appear when requested == observed.
        #expect(general?.rows.contains { $0.label == "Requested Mode" } == false)
        let video = info.sections.first { $0.title == "Video" }
        #expect(video?.rows.contains { $0.isMismatch } == false)
        #expect(video?.badge == .directPlay)
    }

    @Test("delivered diverges: video shows mismatch, badge flips to Transcode, Requested Mode row appears")
    func deliveredDivergesShowsTranscode() {
        // The bug case in the screenshot: source HEVC 4K HDR10, but
        // AVPlayer is decoding H.264 1080p SDR because Jellyfin
        // silently transcoded due to missing DeviceProfile.
        let info = PlaybackInfoBuilder.build(
            item: makeFullItem(container: "mkv", videoRangeType: "HDR10"),
            mode: .remux,                // client requested Remux
            subtitleDisplay: nil,
            delivered: DeliveredStreamInfo(
                videoCodec: "avc1",       // ⇒ h264
                videoWidth: 1920, videoHeight: 1080,
                videoRange: "SDR",
                videoBitrate: nil,
                audioCodec: "ec-3",       // audio matched
                audioChannels: 6
            )
        )
        let video = info.sections.first { $0.title == "Video" }
        let codec = video?.rows.first { $0.label == "Codec" }
        #expect(codec?.value == "HEVC")
        #expect(codec?.delivered == "H264")
        #expect(codec?.isMismatch == true)

        let resolution = video?.rows.first { $0.label == "Resolution" }
        #expect(resolution?.value == "3840 × 2160")
        #expect(resolution?.delivered == "1920 × 1080")
        #expect(resolution?.isMismatch == true)

        // Section badge reflects observed reality, not requested mode.
        #expect(video?.badge == .transcode)

        // General section: Play Method is the *observed* mode, and a
        // separate Requested Mode row exposes the disagreement.
        let general = info.sections.first { $0.title == "General" }
        #expect(general?.rows.first(where: { $0.label == "Play Method" })?.value == "Transcode")
        #expect(general?.rows.first(where: { $0.label == "Requested Mode" })?.value == "Remux")
        #expect(general?.badge == .transcode)
    }

    @Test("normalizeCodec: AVFoundation FourCC values map to Jellyfin codec vocabulary")
    func normalizeCodecMatrix() {
        #expect(PlaybackInfoBuilder.normalizeCodec("avc1") == "h264")
        #expect(PlaybackInfoBuilder.normalizeCodec("hvc1") == "hevc")
        #expect(PlaybackInfoBuilder.normalizeCodec("hev1") == "hevc")
        #expect(PlaybackInfoBuilder.normalizeCodec("ec-3") == "eac3")
        #expect(PlaybackInfoBuilder.normalizeCodec("ac-3") == "ac3")
        #expect(PlaybackInfoBuilder.normalizeCodec("mp4a") == "aac")
        #expect(PlaybackInfoBuilder.normalizeCodec("vp09") == "vp9")
        #expect(PlaybackInfoBuilder.normalizeCodec("UnknownCodec") == "unknowncodec")
    }

    @Test("build: full realistic payload produces expected video rows")
    func buildFullPayload() {
        let item = makeFullItem()
        let info = PlaybackInfoBuilder.build(item: item, mode: .directPlay, subtitleDisplay: "English")
        let video = info.sections.first { $0.title == "Video" }?.rows ?? []

        let codec = video.first { $0.label == "Codec" }?.value
        let resolution = video.first { $0.label == "Resolution" }?.value
        let bitrate = video.first { $0.label == "Bitrate" }?.value
        let range = video.first { $0.label == "Range" }?.value

        #expect(codec == "HEVC")
        #expect(resolution == "3840 × 2160")
        #expect(bitrate == "50 Mbps")
        #expect(range == "Dolby Vision")
    }

    // MARK: - Helpers

    private func makeStream(
        type: String = "Video",
        codec: String? = nil,
        channels: Int? = nil,
        channelLayout: String? = nil,
        videoRange: String? = nil,
        videoRangeType: String? = nil
    ) -> MediaStream {
        MediaStream(
            index: 0, type: type, codec: codec, profile: nil,
            width: nil, height: nil, bitRate: nil,
            language: nil, displayTitle: nil, title: nil,
            isExternal: nil, isDefault: nil,
            channels: channels, channelLayout: channelLayout, sampleRate: nil,
            videoRange: videoRange, videoRangeType: videoRangeType
        )
    }

    private func makeItem(withMediaSources: Bool = true) -> MediaItem {
        let source: MediaSource? = withMediaSources
            ? MediaSource(id: "s1", name: nil, size: nil, container: "mp4",
                          bitrate: nil, mediaStreams: [])
            : nil
        return MediaItem(
            id: "1", name: "Test", type: "Movie",
            overview: nil, productionYear: nil, communityRating: nil,
            officialRating: nil, runTimeTicks: nil, imageTags: nil,
            imageBlurHashes: nil, userData: nil, seriesName: nil,
            seriesId: nil, seasonId: nil, indexNumber: nil,
            parentIndexNumber: nil, premiereDate: nil, genres: nil,
            studios: nil, people: nil, taglines: nil,
            mediaSources: source.map { [$0] },
            criticRating: nil, providerIds: nil, externalUrls: nil,
            remoteTrailers: nil, chapters: nil,
            parentLogoItemId: nil, parentLogoImageTag: nil
        )
    }

    private func makeFullItem(
        container: String = "mkv",
        videoRangeType: String = "DOVI"
    ) -> MediaItem {
        let video = MediaStream(
            index: 0, type: "Video", codec: "hevc", profile: "Main 10",
            width: 3840, height: 2160, bitRate: 50_000_000,
            language: nil, displayTitle: nil, title: nil,
            isExternal: false, isDefault: true,
            channels: nil, channelLayout: nil, sampleRate: nil,
            videoRange: "HDR", videoRangeType: videoRangeType
        )
        let audio = MediaStream(
            index: 1, type: "Audio", codec: "eac3", profile: nil,
            width: nil, height: nil, bitRate: 640_000,
            language: "eng", displayTitle: nil, title: nil,
            isExternal: false, isDefault: true,
            channels: 6, channelLayout: "5.1", sampleRate: 48000,
            videoRange: nil, videoRangeType: nil
        )
        let source = MediaSource(
            id: "s1", name: nil, size: 4_509_715_660, container: container,
            bitrate: 50_640_000, mediaStreams: [video, audio]
        )
        return MediaItem(
            id: "1", name: "Dune", type: "Movie",
            overview: nil, productionYear: 2021, communityRating: nil,
            officialRating: nil, runTimeTicks: nil, imageTags: nil,
            imageBlurHashes: nil, userData: nil, seriesName: nil,
            seriesId: nil, seasonId: nil, indexNumber: nil,
            parentIndexNumber: nil, premiereDate: nil, genres: nil,
            studios: nil, people: nil, taglines: nil,
            mediaSources: [source],
            criticRating: nil, providerIds: nil, externalUrls: nil,
            remoteTrailers: nil, chapters: nil,
            parentLogoItemId: nil, parentLogoImageTag: nil
        )
    }
}
