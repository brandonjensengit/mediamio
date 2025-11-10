//
//  LibraryCategory.swift
//  MediaMio
//
//  Created by Claude Code
//

import Foundation

/// Represents a category in the Library tab (Movies, TV Shows)
enum LibraryCategory: String, CaseIterable, Identifiable {
    case movies = "Movies"
    case tvShows = "TV Shows"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }

    /// Item types to filter by for this category
    var itemTypes: [String] {
        switch self {
        case .movies:
            return ["Movie"]
        case .tvShows:
            return ["Series"]
        }
    }

    /// Filter library items to find matching library for this category
    func matchingLibrary(from libraries: [Library]) -> Library? {
        switch self {
        case .movies:
            return libraries.first { $0.isMovieLibrary }
        case .tvShows:
            return libraries.first { $0.isTVLibrary }
        }
    }
}
