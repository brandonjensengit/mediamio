//
//  Library.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation

// MARK: - Library
struct Library: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let collectionType: String?
    let imageTags: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case collectionType = "CollectionType"
        case imageTags = "ImageTags"
    }

    var isMovieLibrary: Bool {
        collectionType == "movies"
    }

    var isTVLibrary: Bool {
        collectionType == "tvshows"
    }

    var isMusicLibrary: Bool {
        collectionType == "music"
    }

    var displayIcon: String {
        switch collectionType {
        case "movies":
            return "film.fill"
        case "tvshows":
            return "tv.fill"
        case "music":
            return "music.note"
        default:
            return "folder.fill"
        }
    }
}

// MARK: - Libraries Response
struct LibrariesResponse: Codable {
    let items: [Library]
    let totalRecordCount: Int?

    enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

// MARK: - Content Section
struct ContentSection: Identifiable {
    let id = UUID()
    let title: String
    var items: [MediaItem]
    let type: SectionType

    enum SectionType: Hashable {
        case continueWatching
        case recentlyAdded
        case library(id: String, name: String)
        case recommended
        case favorites

        var analyticsName: String {
            switch self {
            case .continueWatching:
                return "continue_watching"
            case .recentlyAdded:
                return "recently_added"
            case .library(_, let name):
                return "library_\(name.lowercased())"
            case .recommended:
                return "recommended"
            case .favorites:
                return "favorites"
            }
        }
    }

    var isEmpty: Bool {
        items.isEmpty
    }

    var count: Int {
        items.count
    }
}
