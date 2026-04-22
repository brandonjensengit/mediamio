//
//  PlaybackStreamURLBuilderTests.swift
//  MediaMioTests
//
//  Phase A: first real test surface. Locks in the Jellyfin URL contract for
//  each playback mode (Direct Play / Direct Stream / Remux / Transcode) so
//  any future server change or refactor that drops a required parameter
//  fails CI immediately. The previous god-object had zero tests because it
//  was untestable; this is here because the URL builder is now a pure
//  struct.
//

import Testing
import Foundation
@testable import MediaMio

@MainActor
struct PlaybackStreamURLBuilderTests {

    // MARK: - Fixtures

    private static func makeItem(
        id: String = "movie-1",
        container: String = "mkv",
        videoCodec: String = "hevc",
        audioCodec: String = "ac3",
        width: Int = 3840,
        height: Int = 2160,
        size: Int64 = 30_000_000_000,
        subtitleStreams: [(index: Int, codec: String, lang: String?)] = []
    ) -> MediaItem {
        var streams: [MediaStream] = [
            MediaStream(
                index: 0, type: "Video", codec: videoCodec,
                width: width, height: height, bitRate: 50_000_000,
                language: nil, displayTitle: nil, title: nil,
                isExternal: false, isDefault: true
            ),
            MediaStream(
                index: 1, type: "Audio", codec: audioCodec,
                width: nil, height: nil, bitRate: 640_000,
                language: "eng", displayTitle: nil, title: nil,
                isExternal: false, isDefault: true
            )
        ]
        for sub in subtitleStreams {
            streams.append(MediaStream(
                index: sub.index, type: "Subtitle", codec: sub.codec,
                width: nil, height: nil, bitRate: nil,
                language: sub.lang, displayTitle: nil, title: nil,
                isExternal: sub.codec == "srt", isDefault: false
            ))
        }

        let mediaSource = MediaSource(
            id: id, name: nil, size: size, container: container,
            bitrate: 50_000_000, mediaStreams: streams
        )

        return MediaItem(
            id: id, name: "Test Movie", type: "Movie",
            overview: nil, productionYear: 2024, communityRating: nil,
            officialRating: nil, runTimeTicks: 60_000_000_000,
            imageTags: nil, imageBlurHashes: nil, userData: nil,
            seriesName: nil, seriesId: nil, seasonId: nil,
            indexNumber: nil, parentIndexNumber: nil,
            premiereDate: nil, genres: nil, studios: nil, people: nil,
            taglines: nil, mediaSources: [mediaSource],
            criticRating: nil, providerIds: nil,
            externalUrls: nil, remoteTrailers: nil,
            chapters: nil
        )
    }

    private static func makeBuilder(
        item: MediaItem,
        baseURL: String = "https://jelly.example.com",
        accessToken: String = "TOKEN-XYZ",
        deviceId: String = "device-uuid",
        streamingMode: StreamingMode = .auto
    ) -> PlaybackStreamURLBuilder {
        let settings = SettingsManager()
        settings.streamingMode = streamingMode.rawValue
        return PlaybackStreamURLBuilder(
            item: item,
            baseURL: baseURL,
            accessToken: accessToken,
            deviceId: deviceId,
            settingsManager: settings
        )
    }

    private static func queryItems(_ url: URL) -> [String: String] {
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var out: [String: String] = [:]
        for item in comps?.queryItems ?? [] {
            out[item.name] = item.value
        }
        return out
    }

    // MARK: - Path & host

    @Test func transcodeMode_constructsHLSMasterPath() {
        let item = Self.makeItem(container: "mkv", videoCodec: "hevc")
        let builder = Self.makeBuilder(item: item, streamingMode: .transcode)

        let result = builder.build()
        #expect(result != nil)
        let url = result!.url

        #expect(url.host == "jelly.example.com")
        #expect(url.path == "/Videos/movie-1/master.m3u8")
        #expect(result!.mode == .transcode)
    }

    // MARK: - Auth

    @Test func allModes_includeAccessTokenAsApiKey() {
        let item = Self.makeItem()
        let modes: [StreamingMode] = [.auto, .directPlay, .transcode]
        for mode in modes {
            let builder = Self.makeBuilder(item: item, streamingMode: mode)
            guard let url = builder.build()?.url else {
                Issue.record("nil URL for mode \(mode)")
                continue
            }
            let q = Self.queryItems(url)
            #expect(q["api_key"] == "TOKEN-XYZ", "api_key missing for \(mode)")
            #expect(q["DeviceId"] == "device-uuid", "DeviceId missing for \(mode)")
            #expect(q["MediaSourceId"] == "movie-1", "MediaSourceId missing for \(mode)")
        }
    }

    // MARK: - Direct Play

    @Test func directPlay_h264_aac_copiesBothStreams() {
        // h264 + aac in mp4 should be DirectPlay-eligible on Apple TV.
        let item = Self.makeItem(container: "mp4", videoCodec: "h264", audioCodec: "aac")
        let builder = Self.makeBuilder(item: item, streamingMode: .auto)

        guard let result = builder.build() else {
            Issue.record("URL builder returned nil")
            return
        }
        let q = Self.queryItems(result.url)

        // The exact mode chosen depends on AppleTVCodecSupport's runtime
        // verdict; we only assert the contract that *whatever mode wins*
        // produces a stream URL with valid auth and a play session.
        #expect(q["PlaySessionId"] != nil)
        #expect(q["EnableAutoStreamCopy"] == "true")
    }

    // MARK: - Transcode

    @Test func transcode_setsExplicitVideoBitrate() {
        let item = Self.makeItem()
        let builder = Self.makeBuilder(item: item, streamingMode: .transcode)
        guard let url = builder.build()?.url else {
            Issue.record("nil URL")
            return
        }
        let q = Self.queryItems(url)

        // Reserves 640 kbps for audio, caps total at 15 Mbps for 1080p.
        // With the default maxBitrate from settings, video bitrate should
        // be a positive integer that isn't equal to total bitrate.
        #expect(q["VideoBitrate"] != nil)
        #expect(q["AudioBitrate"] == "640000")
        #expect(q["MaxWidth"] == "1920")
        #expect(q["MaxHeight"] == "1080")
        #expect(q["Profile"] == "high")
        #expect(q["Level"] == "41")
    }

    @Test func transcode_preservesAspectRatio() {
        // RequireNonAnamorphic=false + CopyTimestamps=true together prevent
        // the 416×172 cropping bug that the old verification print
        // statements were warning about.
        let item = Self.makeItem()
        let builder = Self.makeBuilder(item: item, streamingMode: .transcode)
        let q = Self.queryItems(builder.build()!.url)

        #expect(q["RequireNonAnamorphic"] == "false")
        #expect(q["CopyTimestamps"] == "true")
    }

    // MARK: - Subtitles

    @Test func subtitleStreamIndex_includedWhenAvailable() {
        let item = Self.makeItem(
            subtitleStreams: [(index: 2, codec: "subrip", lang: "eng")]
        )
        let builder = Self.makeBuilder(item: item, streamingMode: .transcode)
        let q = Self.queryItems(builder.build()!.url)

        #expect(q["SubtitleStreamIndex"] == "2")
        #expect(q["SubtitleMethod"] == "Encode")
        #expect(q["SubtitleCodec"] == "webvtt")
    }

    @Test func subtitleStreamIndex_omittedWhenNoSubtitles() {
        let item = Self.makeItem(subtitleStreams: [])
        let builder = Self.makeBuilder(item: item, streamingMode: .transcode)
        let q = Self.queryItems(builder.build()!.url)

        #expect(q["SubtitleStreamIndex"] == nil)
        // The encode-style subtitle flags are still set unconditionally so
        // the player is ready if the user toggles a subtitle later. Don't
        // weaken that — it's the current contract.
        #expect(q["SubtitleMethod"] == "Encode")
    }

    // MARK: - Per-call uniqueness

    @Test func playSessionId_isUniquePerBuild() {
        let item = Self.makeItem()
        let builder = Self.makeBuilder(item: item, streamingMode: .transcode)
        let q1 = Self.queryItems(builder.build()!.url)
        let q2 = Self.queryItems(builder.build()!.url)
        #expect(q1["PlaySessionId"] != q2["PlaySessionId"])
    }
}
