//
//  ContentRatingTests.swift
//  MediaMioTests
//
//  Locks the rating → rank comparator and the `ContentRatingLevel.isAllowed`
//  predicate. These are the silent-breakage risks: if a mapping drifts or a
//  tier's ceiling changes, the bug is invisible in the UI — parental controls
//  just quietly leak mature content. These tests make the regression fail CI.
//

import Testing
import Foundation
@testable import MediaMio

struct ContentRatingTests {

    // MARK: - rank(for:)

    @Test
    func ranksKnownMovieRatingsInOrder() {
        let g = ContentRating.rank(for: "G") ?? -1
        let pg = ContentRating.rank(for: "PG") ?? -1
        let pg13 = ContentRating.rank(for: "PG-13") ?? -1
        let r = ContentRating.rank(for: "R") ?? -1
        let nc17 = ContentRating.rank(for: "NC-17") ?? -1

        #expect(g < pg)
        #expect(pg < pg13)
        #expect(pg13 < r)
        #expect(r < nc17)
    }

    @Test
    func ranksKnownTVRatingsInOrder() {
        let tvy = ContentRating.rank(for: "TV-Y") ?? -1
        let tvg = ContentRating.rank(for: "TV-G") ?? -1
        let tvy7 = ContentRating.rank(for: "TV-Y7") ?? -1
        let tvpg = ContentRating.rank(for: "TV-PG") ?? -1
        let tv14 = ContentRating.rank(for: "TV-14") ?? -1
        let tvma = ContentRating.rank(for: "TV-MA") ?? -1

        #expect(tvy < tvpg)
        #expect(tvg < tvpg)
        #expect(tvy7 < tvpg)
        #expect(tvpg < tv14)
        #expect(tv14 < tvma)
    }

    @Test
    func unknownRatingReturnsNil() {
        #expect(ContentRating.rank(for: nil) == nil)
        #expect(ContentRating.rank(for: "") == nil)
        #expect(ContentRating.rank(for: "   ") == nil)
        #expect(ContentRating.rank(for: "Approved") == nil)
        #expect(ContentRating.rank(for: "Not Rated") == nil)
        #expect(ContentRating.rank(for: "18+") == nil)
    }

    @Test
    func rankIsCaseInsensitiveAndTrimmed() {
        // Servers in the wild return mixed case and stray whitespace.
        #expect(ContentRating.rank(for: "pg-13") == ContentRating.rank(for: "PG-13"))
        #expect(ContentRating.rank(for: "  pg  ") == ContentRating.rank(for: "PG"))
        #expect(ContentRating.rank(for: "tv-ma") == ContentRating.rank(for: "TV-MA"))
    }

    // MARK: - isAllowed(officialRating:under:)

    @Test
    func familyOnlyAllowsOnlyG() {
        #expect(ContentRating.isAllowed(officialRating: "G", under: .familyOnly))
        #expect(ContentRating.isAllowed(officialRating: "TV-Y", under: .familyOnly))
        #expect(ContentRating.isAllowed(officialRating: "TV-G", under: .familyOnly))

        #expect(!ContentRating.isAllowed(officialRating: "PG", under: .familyOnly))
        #expect(!ContentRating.isAllowed(officialRating: "PG-13", under: .familyOnly))
        #expect(!ContentRating.isAllowed(officialRating: "R", under: .familyOnly))
        #expect(!ContentRating.isAllowed(officialRating: "TV-MA", under: .familyOnly))
    }

    @Test
    func teenAllowsUpToPG13AndTV14() {
        #expect(ContentRating.isAllowed(officialRating: "G", under: .teen))
        #expect(ContentRating.isAllowed(officialRating: "PG", under: .teen))
        #expect(ContentRating.isAllowed(officialRating: "PG-13", under: .teen))
        #expect(ContentRating.isAllowed(officialRating: "TV-14", under: .teen))

        #expect(!ContentRating.isAllowed(officialRating: "R", under: .teen))
        #expect(!ContentRating.isAllowed(officialRating: "TV-MA", under: .teen))
        #expect(!ContentRating.isAllowed(officialRating: "NC-17", under: .teen))
    }

    @Test
    func matureAllowsRButNotNC17() {
        // `mature` is the most permissive defined tier. NC-17 is always blocked
        // — this matches the Netflix "Adults" profile behavior.
        #expect(ContentRating.isAllowed(officialRating: "R", under: .mature))
        #expect(ContentRating.isAllowed(officialRating: "TV-MA", under: .mature))

        #expect(!ContentRating.isAllowed(officialRating: "NC-17", under: .mature))
        #expect(!ContentRating.isAllowed(officialRating: "X", under: .mature))
    }

    @Test
    func unknownRatingIsBlockedUnderEveryTier() {
        // Defense in depth: if we can't classify, we don't show it.
        for level in ContentRatingLevel.allCases {
            #expect(!ContentRating.isAllowed(officialRating: nil, under: level))
            #expect(!ContentRating.isAllowed(officialRating: "", under: level))
            #expect(!ContentRating.isAllowed(officialRating: "Unrated", under: level))
        }
    }

    // MARK: - jellyfinMaxRating

    @Test
    func jellyfinMaxRatingMatchesTier() {
        #expect(ContentRatingLevel.familyOnly.jellyfinMaxRating == "G")
        #expect(ContentRatingLevel.kids.jellyfinMaxRating == "PG")
        #expect(ContentRatingLevel.teen.jellyfinMaxRating == "PG-13")
        #expect(ContentRatingLevel.mature.jellyfinMaxRating == "R")
    }

    // MARK: - ParentalControlsConfig

    @Test
    func disabledConfigReturnsNoMaxRatingAndNoFilter() {
        let config = ParentalControlsConfig(isEnabled: false, maxLevel: .teen)
        #expect(config.jellyfinMaxRating == nil)

        let items = [makeItem(rating: "R"), makeItem(rating: "G"), makeItem(rating: nil)]
        #expect(config.filter(items).count == items.count)
    }

    @Test
    func enabledConfigFiltersByTier() {
        let config = ParentalControlsConfig(isEnabled: true, maxLevel: .kids)
        #expect(config.jellyfinMaxRating == "PG")

        let items = [
            makeItem(rating: "G"),       // allowed
            makeItem(rating: "PG"),      // allowed
            makeItem(rating: "PG-13"),   // blocked
            makeItem(rating: "R"),       // blocked
            makeItem(rating: nil)        // blocked (unknown)
        ]
        let filtered = config.filter(items)
        #expect(filtered.map(\.officialRating) == ["G", "PG"])
    }

    private func makeItem(rating: String?) -> MediaItem {
        MediaItem(
            id: UUID().uuidString, name: "x", type: "Movie",
            overview: nil, productionYear: nil, communityRating: nil,
            officialRating: rating, runTimeTicks: nil,
            imageTags: nil, imageBlurHashes: nil, userData: nil,
            seriesName: nil, seriesId: nil, seasonId: nil,
            indexNumber: nil, parentIndexNumber: nil,
            premiereDate: nil, genres: nil, studios: nil, people: nil,
            taglines: nil, mediaSources: nil,
            criticRating: nil, providerIds: nil,
            externalUrls: nil, remoteTrailers: nil, chapters: nil,
            parentLogoItemId: nil, parentLogoImageTag: nil
        )
    }
}
