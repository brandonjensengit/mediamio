//
//  ChapterTests.swift
//  MediaMioTests
//
//  Locks in Jellyfin's wire format for the Chapter sub-object on a MediaItem
//  details response. If the server ever renames `StartPositionTicks` or
//  changes the tick base, the detail screen's chapter scrubber will silently
//  go blank — these tests make that fail CI instead.
//

import Testing
import Foundation
@testable import MediaMio

struct ChapterTests {

    @Test
    func decodesChapterPayload() throws {
        let json = #"""
        {
            "Name": "Opening Titles",
            "StartPositionTicks": 6000000000,
            "ImageTag": "abc123",
            "ImageDateModified": "2024-01-01T00:00:00Z"
        }
        """#.data(using: .utf8)!

        let chapter = try JSONDecoder().decode(Chapter.self, from: json)
        #expect(chapter.name == "Opening Titles")
        #expect(chapter.startPositionTicks == 6_000_000_000)
        #expect(chapter.imageTag == "abc123")
        // 6_000_000_000 ticks = 600 seconds = 10 minutes
        #expect(chapter.startSeconds == 600.0)
        #expect(chapter.formattedStart == "10:00")
        #expect(chapter.displayName == "Opening Titles")
    }

    @Test
    func chapterWithoutNameUsesFormattedStart() throws {
        let json = #"""
        {
            "StartPositionTicks": 54000000000,
            "ImageTag": null
        }
        """#.data(using: .utf8)!

        let chapter = try JSONDecoder().decode(Chapter.self, from: json)
        // 54_000_000_000 ticks = 5400 seconds = 1:30:00
        #expect(chapter.startSeconds == 5400.0)
        #expect(chapter.formattedStart == "1:30:00")
        #expect(chapter.displayName == "1:30:00")
    }

    @Test
    func imageURLIndexesByPosition() {
        let item = MediaItem(
            id: "movie-42", name: "Test", type: "Movie",
            overview: nil, productionYear: nil, communityRating: nil,
            officialRating: nil, runTimeTicks: nil,
            imageTags: nil, imageBlurHashes: nil, userData: nil,
            seriesName: nil, seriesId: nil, seasonId: nil,
            indexNumber: nil, parentIndexNumber: nil,
            premiereDate: nil, genres: nil, studios: nil, people: nil,
            taglines: nil, mediaSources: nil,
            criticRating: nil, providerIds: nil,
            externalUrls: nil, remoteTrailers: nil,
            chapters: nil
        )
        let url = item.chapterImageURL(
            baseURL: "https://jelly.example.com",
            chapterIndex: 3,
            maxWidth: 400
        )
        #expect(url == "https://jelly.example.com/Items/movie-42/Images/Chapter/3?maxWidth=400&quality=85")
    }
}
