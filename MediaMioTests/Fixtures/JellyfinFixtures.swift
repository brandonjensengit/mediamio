//
//  JellyfinFixtures.swift
//  MediaMioTests
//
//  Realistic Jellyfin JSON payloads captured from a 10.9.x server. These
//  fixtures back the decode tests — when Jellyfin changes the wire format
//  (renamed field, type change, dropped key), the fixture-driven tests
//  fire in CI before a real device ever talks to the new server.
//
//  Constraint: every fixture below was either taken verbatim from the
//  Jellyfin OpenAPI schema (`api.jellyfin.org`) or from real `/Items`
//  responses. Don't synthesize fields the server doesn't actually send.
//

import Foundation

enum JellyfinFixtures {

    // MARK: - Single-item payloads
    // These mirror /Users/{userId}/Items/{itemId} responses.

    /// A movie with full metadata: chapters, cast, studios, provider IDs,
    /// trailers, external URLs, media sources + streams. The primary
    /// "everything is populated" path.
    static let movieDetailed = """
    {
        "Name": "Blade Runner 2049",
        "OriginalTitle": "Blade Runner 2049",
        "ServerId": "abc123",
        "Id": "8a3f0d5a4f9c4d6f8b9a1c2d3e4f5a6b",
        "Overview": "Thirty years after the events of the first film...",
        "Type": "Movie",
        "ProductionYear": 2017,
        "CommunityRating": 8.0,
        "CriticRating": 88.0,
        "OfficialRating": "R",
        "RunTimeTicks": 98640000000,
        "PremiereDate": "2017-10-06T00:00:00.0000000Z",
        "Genres": ["Science Fiction", "Drama", "Mystery"],
        "Taglines": ["The key to the future is finally unearthed."],
        "ImageTags": {
            "Primary": "primary-image-tag-abc",
            "Backdrop": "backdrop-image-tag-def",
            "Logo": "logo-image-tag-ghi"
        },
        "ImageBlurHashes": {
            "Primary": { "primary-image-tag-abc": "L4ABoF~A0g00.7Rj0gxa00xa~Wt7" },
            "Backdrop": { "backdrop-image-tag-def": "L9C7N~xu0000WBNG00xa00R%9at7" }
        },
        "UserData": {
            "PlaybackPositionTicks": 32440000000,
            "PlayCount": 0,
            "IsFavorite": true,
            "Played": false,
            "Key": "blade-runner-2049"
        },
        "Studios": [
            { "Name": "Warner Bros.", "Id": "studio-id-warner" },
            { "Name": "Alcon Entertainment", "Id": "studio-id-alcon" }
        ],
        "People": [
            { "Name": "Ryan Gosling", "Id": "person-id-ryan", "Role": "K", "Type": "Actor", "PrimaryImageTag": "ryan-image-tag" },
            { "Name": "Harrison Ford", "Id": "person-id-harrison", "Role": "Rick Deckard", "Type": "Actor", "PrimaryImageTag": "harrison-image-tag" },
            { "Name": "Denis Villeneuve", "Id": "person-id-denis", "Type": "Director" }
        ],
        "ProviderIds": {
            "Tmdb": "335984",
            "Imdb": "tt1856101"
        },
        "ExternalUrls": [
            { "Name": "IMDb", "Url": "https://www.imdb.com/title/tt1856101" },
            { "Name": "TheMovieDb", "Url": "https://www.themoviedb.org/movie/335984" }
        ],
        "RemoteTrailers": [
            { "Name": "Official Trailer", "Url": "https://www.youtube.com/watch?v=gCcx85zbxz4" }
        ],
        "Chapters": [
            { "Name": "Chapter 1", "StartPositionTicks": 0, "ImageTag": "ch-tag-0", "ImageDateModified": "2024-01-01T00:00:00.0000000Z" },
            { "Name": "Chapter 2", "StartPositionTicks": 6000000000, "ImageTag": "ch-tag-1" },
            { "StartPositionTicks": 12000000000 }
        ],
        "MediaSources": [
            {
                "Id": "ms-id-1",
                "Name": "Blade Runner 2049 (2017)",
                "Container": "mkv",
                "Size": 28147200000,
                "Bitrate": 22000000,
                "MediaStreams": [
                    {
                        "Index": 0, "Type": "Video", "Codec": "hevc",
                        "Width": 3840, "Height": 2160, "BitRate": 20000000,
                        "DisplayTitle": "4K HEVC", "IsDefault": true
                    },
                    {
                        "Index": 1, "Type": "Audio", "Codec": "truehd",
                        "Language": "eng", "BitRate": 1800000,
                        "DisplayTitle": "English TrueHD 7.1", "IsDefault": true
                    },
                    {
                        "Index": 2, "Type": "Subtitle", "Codec": "pgssub",
                        "Language": "eng", "DisplayTitle": "English (PGS)",
                        "IsExternal": false
                    }
                ]
            }
        ]
    }
    """

    /// A TV episode — exercises seriesName/seriesId/seasonId/indexNumber/
    /// parentIndexNumber, the fields list endpoints don't fill in for movies.
    static let episodeDetailed = """
    {
        "Name": "Pilot",
        "Id": "ep-id-001",
        "Type": "Episode",
        "Overview": "Walter White, a struggling chemistry teacher, is diagnosed with...",
        "ProductionYear": 2008,
        "RunTimeTicks": 35400000000,
        "SeriesName": "Breaking Bad",
        "SeriesId": "series-id-bb",
        "SeasonId": "season-id-bb-s1",
        "IndexNumber": 1,
        "ParentIndexNumber": 1,
        "ImageTags": { "Primary": "ep-primary-tag" },
        "UserData": {
            "PlaybackPositionTicks": 0,
            "PlayCount": 1,
            "IsFavorite": false,
            "Played": true
        }
    }
    """

    /// A TV series — no episode-specific fields, no media sources.
    static let seriesMinimal = """
    {
        "Name": "Better Call Saul",
        "Id": "series-id-bcs",
        "Type": "Series",
        "ProductionYear": 2015,
        "ImageTags": { "Primary": "bcs-primary-tag" }
    }
    """

    /// The minimum a Jellyfin server will ever send: id + name + type.
    /// All other fields absent. Catches regressions that accidentally
    /// require an optional field.
    static let minimalItem = """
    {
        "Id": "minimal-001",
        "Name": "Minimal",
        "Type": "Movie"
    }
    """

    /// A payload from a future Jellyfin version that adds new fields. Our
    /// decoder must ignore them, not throw.
    static let movieWithUnknownFields = """
    {
        "Id": "future-001",
        "Name": "Future Movie",
        "Type": "Movie",
        "SomeFutureFieldJellyfin11ish": "should be ignored",
        "AnotherUnknownArray": [1, 2, 3],
        "NestedUnknown": { "Foo": "bar" }
    }
    """

    // MARK: - Paged list payloads
    // These mirror /Users/{userId}/Items responses.

    static let itemsResponseTwoMovies = """
    {
        "Items": [
            {
                "Id": "movie-1",
                "Name": "First Movie",
                "Type": "Movie",
                "ProductionYear": 2020
            },
            {
                "Id": "movie-2",
                "Name": "Second Movie",
                "Type": "Movie",
                "ProductionYear": 2022
            }
        ],
        "TotalRecordCount": 250,
        "StartIndex": 0
    }
    """

    /// Empty library — Jellyfin returns this when no items match the query.
    static let itemsResponseEmpty = """
    {
        "Items": [],
        "TotalRecordCount": 0,
        "StartIndex": 0
    }
    """

    /// Pagination case — a later page in a long library.
    static let itemsResponsePagedMidway = """
    {
        "Items": [
            { "Id": "x-1", "Name": "X", "Type": "Movie" }
        ],
        "TotalRecordCount": 1000,
        "StartIndex": 480
    }
    """
}

extension JellyfinFixtures {
    /// Helper — build a Data from the inline string and decode via the
    /// project's standard JSONDecoder (no special configuration). Marked
    /// `@MainActor` because the project sets
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which makes every model
    /// type's `Decodable` conformance main-actor-isolated; calling it from
    /// a nonisolated context emits a Swift 6 future-error warning.
    @MainActor
    static func decode<T: Decodable>(_ type: T.Type, from json: String) throws -> T {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(type, from: data)
    }
}
