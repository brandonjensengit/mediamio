//
//  MediaItemDecodingTests.swift
//  MediaMioTests
//
//  Locks the Jellyfin → MediaItem wire contract. Every test here decodes
//  a JSON fixture taken from a real Jellyfin response and asserts the
//  fields land on the right Swift properties. When Jellyfin renames a
//  field, removes one, or changes a type, these tests fail in CI before
//  a real device sees the new server.
//
//  See `Fixtures/JellyfinFixtures.swift` for the source JSON.
//

import Testing
import Foundation
@testable import MediaMio

@MainActor
struct MediaItemDecodingTests {

    // MARK: - Movie (full payload)

    @Test("Detailed movie payload decodes top-level scalars")
    func movieDecodesScalars() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        #expect(item.id == "8a3f0d5a4f9c4d6f8b9a1c2d3e4f5a6b")
        #expect(item.name == "Blade Runner 2049")
        #expect(item.type == "Movie")
        #expect(item.productionYear == 2017)
        #expect(item.communityRating == 8.0)
        #expect(item.criticRating == 88.0)
        #expect(item.officialRating == "R")
        #expect(item.runTimeTicks == 98_640_000_000)
        #expect(item.isMovie == true)
        #expect(item.isEpisode == false)
    }

    @Test("Movie payload decodes runtime helper")
    func movieDecodesRuntimeHelpers() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        #expect(item.runtimeMinutes == 164)
        #expect(item.runtimeFormatted == "2h 44m")
        #expect(item.yearText == "2017")
        #expect(item.ratingText == "8.0")
    }

    @Test("Movie payload decodes nested ImageTags")
    func movieDecodesImageTags() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        #expect(item.imageTags?.primary == "primary-image-tag-abc")
        #expect(item.imageTags?.backdrop == "backdrop-image-tag-def")
        #expect(item.imageTags?.logo == "logo-image-tag-ghi")
        #expect(item.imageTags?.thumb == nil)
        #expect(item.imageTags?.banner == nil)
    }

    @Test("Movie payload decodes UserData with playback position")
    func movieDecodesUserData() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        let ud = try #require(item.userData)
        #expect(ud.playbackPositionTicks == 32_440_000_000)
        #expect(ud.playCount == 0)
        #expect(ud.isFavorite == true)
        #expect(ud.played == false)
        #expect(ud.key == "blade-runner-2049")

        // Computed helper should compose against runtimeTicks.
        let pct = ud.playedPercentage(totalTicks: item.runTimeTicks)
        #expect(pct > 32.8 && pct < 33.0)
    }

    @Test("Movie payload decodes studios + people lists")
    func movieDecodesStudiosAndPeople() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        #expect(item.studios?.count == 2)
        #expect(item.studios?.first?.name == "Warner Bros.")
        #expect(item.people?.count == 3)
        let director = item.people?.first(where: { $0.type == "Director" })
        #expect(director?.name == "Denis Villeneuve")
        // Director has no role; role field tolerates absence.
        #expect(director?.role == nil)
    }

    @Test("Movie payload decodes provider IDs as a typed dictionary")
    func movieDecodesProviderIds() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        #expect(item.providerIds?["Tmdb"] == "335984")
        #expect(item.providerIds?["Imdb"] == "tt1856101")
    }

    @Test("Movie payload decodes external URLs (IMDb, TMDB)")
    func movieDecodesExternalUrls() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        let urls = try #require(item.externalUrls)
        #expect(urls.count == 2)
        #expect(urls.first?.name == "IMDb")
        #expect(urls.first?.url == "https://www.imdb.com/title/tt1856101")
    }

    @Test("Movie payload decodes remote trailers")
    func movieDecodesRemoteTrailers() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        #expect(item.remoteTrailers?.count == 1)
        #expect(item.remoteTrailers?.first?.name == "Official Trailer")
        #expect(item.remoteTrailers?.first?.url.contains("youtube.com") == true)
    }

    @Test("Movie payload decodes chapters including chapter without name")
    func movieDecodesChapters() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        let chapters = try #require(item.chapters)
        #expect(chapters.count == 3)
        #expect(chapters[0].name == "Chapter 1")
        #expect(chapters[0].startPositionTicks == 0)
        #expect(chapters[0].imageTag == "ch-tag-0")
        #expect(chapters[1].imageDateModified == nil)
        // Third chapter has no name — displayName falls back to formattedStart.
        #expect(chapters[2].name == nil)
        #expect(chapters[2].displayName == "20:00")
    }

    @Test("Movie payload decodes media sources + nested streams")
    func movieDecodesMediaSources() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        let source = try #require(item.mediaSources?.first)
        #expect(source.container == "mkv")
        #expect(source.size == 28_147_200_000)
        #expect(source.bitrate == 22_000_000)

        let streams = try #require(source.mediaStreams)
        #expect(streams.count == 3)
        let video = streams.first(where: { $0.type == "Video" })
        #expect(video?.codec == "hevc")
        #expect(video?.width == 3840)
        #expect(video?.height == 2160)

        let subtitle = streams.first(where: { $0.type == "Subtitle" })
        #expect(subtitle?.language == "eng")
        #expect(subtitle?.isExternal == false)

        // The MediaItem.subtitleStreams helper should pick up the same one.
        #expect(item.subtitleStreams.count == 1)
        #expect(item.firstSubtitleIndex == 2)
        #expect(item.hasSubtitles == true)
    }

    @Test("Movie payload decodes blur hashes (nested per-tag dict)")
    func movieDecodesBlurHashes() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        let hashes = try #require(item.imageBlurHashes)
        #expect(hashes.primary?["primary-image-tag-abc"]?.hasPrefix("L4") == true)
        #expect(hashes.backdrop?["backdrop-image-tag-def"]?.hasPrefix("L9") == true)
    }

    // MARK: - Episode

    @Test("Episode payload populates SeriesName / SeasonId / IndexNumber")
    func episodeDecodesShowFields() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.episodeDetailed)
        #expect(item.type == "Episode")
        #expect(item.isEpisode == true)
        #expect(item.isMovie == false)
        #expect(item.seriesName == "Breaking Bad")
        #expect(item.seriesId == "series-id-bb")
        #expect(item.seasonId == "season-id-bb-s1")
        #expect(item.indexNumber == 1)
        #expect(item.parentIndexNumber == 1)
        #expect(item.episodeText == "S1E1")
    }

    // MARK: - Series

    @Test("Series payload omits episodic fields without throwing")
    func seriesDecodesWithoutEpisodicFields() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.seriesMinimal)
        #expect(item.type == "Series")
        #expect(item.isSeries == true)
        #expect(item.indexNumber == nil)
        #expect(item.parentIndexNumber == nil)
        #expect(item.episodeText == nil)
        #expect(item.mediaSources == nil)
    }

    // MARK: - Minimal item

    @Test("Minimal item (only Id, Name, Type) decodes without throwing")
    func minimalItemDecodes() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.minimalItem)
        #expect(item.id == "minimal-001")
        #expect(item.name == "Minimal")
        #expect(item.type == "Movie")
        #expect(item.userData == nil)
        #expect(item.imageTags == nil)
        #expect(item.runTimeTicks == nil)
        #expect(item.runtimeMinutes == nil)
        #expect(item.runtimeFormatted == nil)
        #expect(item.subtitleStreams.isEmpty)
        #expect(item.hasSubtitles == false)
    }

    // MARK: - Forward compatibility

    @Test("Unknown future fields do not break decoding")
    func unknownFieldsAreIgnored() throws {
        let item = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieWithUnknownFields)
        #expect(item.id == "future-001")
        #expect(item.name == "Future Movie")
    }

    // MARK: - Round-trip

    @Test("Decoded movie round-trips through encode → decode")
    func movieRoundTripsThroughEncoder() throws {
        let original = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.movieDetailed)
        let encoded = try JSONEncoder().encode(original)
        let redecoded = try JSONDecoder().decode(MediaItem.self, from: encoded)
        #expect(original == redecoded)
    }

    @Test("Decoded episode round-trips through encode → decode")
    func episodeRoundTripsThroughEncoder() throws {
        let original = try JellyfinFixtures.decode(MediaItem.self, from: JellyfinFixtures.episodeDetailed)
        let encoded = try JSONEncoder().encode(original)
        let redecoded = try JSONDecoder().decode(MediaItem.self, from: encoded)
        #expect(original == redecoded)
    }
}
