//
//  ItemsResponseDecodingTests.swift
//  MediaMioTests
//
//  Locks the wire contract for paged list endpoints
//  (`/Users/{userId}/Items`, `/Items`, etc). Same goal as
//  `MediaItemDecodingTests`: catch Jellyfin field renames in CI before
//  they reach a real device.
//

import Testing
import Foundation
@testable import MediaMio

@MainActor
struct ItemsResponseDecodingTests {

    @Test("Two-movie page decodes items + counts")
    func decodesTwoMoviePage() throws {
        let resp = try JellyfinFixtures.decode(
            ItemsResponse.self,
            from: JellyfinFixtures.itemsResponseTwoMovies
        )
        #expect(resp.items.count == 2)
        #expect(resp.totalRecordCount == 250)
        #expect(resp.startIndex == 0)
        #expect(resp.items[0].id == "movie-1")
        #expect(resp.items[1].productionYear == 2022)
    }

    @Test("Empty page decodes with zero items + zero count")
    func decodesEmptyPage() throws {
        let resp = try JellyfinFixtures.decode(
            ItemsResponse.self,
            from: JellyfinFixtures.itemsResponseEmpty
        )
        #expect(resp.items.isEmpty)
        #expect(resp.totalRecordCount == 0)
        #expect(resp.startIndex == 0)
    }

    @Test("Mid-pagination response decodes large totals")
    func decodesMidwayPage() throws {
        let resp = try JellyfinFixtures.decode(
            ItemsResponse.self,
            from: JellyfinFixtures.itemsResponsePagedMidway
        )
        #expect(resp.items.count == 1)
        #expect(resp.totalRecordCount == 1000)
        #expect(resp.startIndex == 480)
    }

    @Test("Items array is required — payload missing it should throw")
    func itemsKeyIsRequired() {
        let badPayload = """
        { "TotalRecordCount": 10, "StartIndex": 0 }
        """
        #expect(throws: DecodingError.self) {
            _ = try JellyfinFixtures.decode(ItemsResponse.self, from: badPayload)
        }
    }

    @Test("Counts are optional — payload without them still decodes")
    func countsAreOptional() throws {
        let payload = """
        { "Items": [ { "Id": "a", "Name": "A", "Type": "Movie" } ] }
        """
        let resp = try JellyfinFixtures.decode(ItemsResponse.self, from: payload)
        #expect(resp.items.count == 1)
        #expect(resp.totalRecordCount == nil)
        #expect(resp.startIndex == nil)
    }
}
