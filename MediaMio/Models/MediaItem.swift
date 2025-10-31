//
//  MediaItem.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation

// MARK: - Media Item
struct MediaItem: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let type: String
    let overview: String?
    let productionYear: Int?
    let communityRating: Double?
    let officialRating: String?
    let runTimeTicks: Int64?
    let imageTags: ImageTags?
    let imageBlurHashes: ImageBlurHashes?
    let userData: UserData?

    // TV Show specific
    let seriesName: String?
    let seriesId: String?
    let seasonId: String?
    let indexNumber: Int?  // Episode number
    let parentIndexNumber: Int?  // Season number

    // Additional metadata
    let premiereDate: String?
    let genres: [String]?
    let studios: [StudioInfo]?
    let people: [PersonInfo]?
    let taglines: [String]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case overview = "Overview"
        case productionYear = "ProductionYear"
        case communityRating = "CommunityRating"
        case officialRating = "OfficialRating"
        case runTimeTicks = "RunTimeTicks"
        case imageTags = "ImageTags"
        case imageBlurHashes = "ImageBlurHashes"
        case userData = "UserData"
        case seriesName = "SeriesName"
        case seriesId = "SeriesId"
        case seasonId = "SeasonId"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case premiereDate = "PremiereDate"
        case genres = "Genres"
        case studios = "Studios"
        case people = "People"
        case taglines = "Taglines"
    }

    // MARK: - Computed Properties

    var isMovie: Bool {
        type == "Movie"
    }

    var isSeries: Bool {
        type == "Series"
    }

    var isEpisode: Bool {
        type == "Episode"
    }

    var runtimeMinutes: Int? {
        guard let ticks = runTimeTicks else { return nil }
        return Int(ticks / 600_000_000) // Convert ticks to minutes
    }

    var runtimeFormatted: String? {
        guard let minutes = runtimeMinutes else { return nil }
        let hours = minutes / 60
        let mins = minutes % 60

        if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    var yearText: String? {
        guard let year = productionYear else { return nil }
        return String(year)
    }

    var ratingText: String? {
        guard let rating = communityRating else { return nil }
        return String(format: "%.1f", rating)
    }

    var episodeText: String? {
        guard isEpisode else { return nil }
        if let season = parentIndexNumber, let episode = indexNumber {
            return "S\(season)E\(episode)"
        }
        return nil
    }

    // MARK: - Image URLs

    func primaryImageURL(baseURL: String, maxWidth: Int = 400, quality: Int = 90) -> String? {
        guard imageTags?.primary != nil else { return nil }
        return "\(baseURL)/Items/\(id)/Images/Primary?maxWidth=\(maxWidth)&quality=\(quality)"
    }

    func backdropImageURL(baseURL: String, maxWidth: Int = 1920, quality: Int = 90) -> String? {
        guard imageTags?.backdrop != nil else { return nil }
        return "\(baseURL)/Items/\(id)/Images/Backdrop?maxWidth=\(maxWidth)&quality=\(quality)"
    }

    func thumbImageURL(baseURL: String, maxWidth: Int = 600, quality: Int = 90) -> String? {
        guard imageTags?.thumb != nil else { return nil }
        return "\(baseURL)/Items/\(id)/Images/Thumb?maxWidth=\(maxWidth)&quality=\(quality)"
    }
}

// MARK: - User Data
struct UserData: Codable, Hashable {
    let playbackPositionTicks: Int64?
    let playCount: Int?
    let isFavorite: Bool?
    let played: Bool?
    let key: String?

    enum CodingKeys: String, CodingKey {
        case playbackPositionTicks = "PlaybackPositionTicks"
        case playCount = "PlayCount"
        case isFavorite = "IsFavorite"
        case played = "Played"
        case key = "Key"
    }

    var playedPercentage: Double {
        // Note: This will be calculated with runtime when displaying
        0.0
    }

    func playedPercentage(totalTicks: Int64?) -> Double {
        guard let position = playbackPositionTicks,
              let total = totalTicks,
              total > 0 else {
            return 0.0
        }
        return Double(position) / Double(total) * 100.0
    }
}

// MARK: - Image Tags
struct ImageTags: Codable, Hashable {
    let primary: String?
    let backdrop: String?
    let thumb: String?
    let logo: String?
    let banner: String?

    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case thumb = "Thumb"
        case logo = "Logo"
        case banner = "Banner"
    }
}

// MARK: - Image Blur Hashes
struct ImageBlurHashes: Codable, Hashable {
    let primary: [String: String]?
    let backdrop: [String: String]?

    enum CodingKeys: String, CodingKey {
        case primary = "Primary"
        case backdrop = "Backdrop"
    }
}

// MARK: - Studio Info
struct StudioInfo: Codable, Hashable {
    let name: String
    let id: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
    }
}

// MARK: - Person Info
struct PersonInfo: Codable, Hashable {
    let name: String
    let id: String?
    let role: String?
    let type: String?
    let primaryImageTag: String?

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
        case role = "Role"
        case type = "Type"
        case primaryImageTag = "PrimaryImageTag"
    }
}

// MARK: - Items Response
struct ItemsResponse: Codable {
    let items: [MediaItem]
    let totalRecordCount: Int?
    let startIndex: Int?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
        case startIndex = "StartIndex"
    }
}
