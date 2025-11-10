//
//  FilterModels.swift
//  MediaMio
//
//  Filter models for library browsing
//

import Foundation

// MARK: - Genre

enum Genre: String, CaseIterable, Codable, Hashable, Identifiable {
    case action = "Action"
    case adventure = "Adventure"
    case animation = "Animation"
    case comedy = "Comedy"
    case crime = "Crime"
    case documentary = "Documentary"
    case drama = "Drama"
    case family = "Family"
    case fantasy = "Fantasy"
    case horror = "Horror"
    case mystery = "Mystery"
    case romance = "Romance"
    case sciFi = "Science Fiction"
    case thriller = "Thriller"
    case war = "War"
    case western = "Western"

    var id: String { rawValue }

    var displayName: String {
        rawValue
    }
}

// MARK: - Library Filters

struct LibraryFilters: Codable, Equatable {
    var selectedGenres: Set<Genre>
    var yearRange: YearRange?
    var minimumRating: Double
    var showWatched: Bool
    var showUnwatched: Bool

    init(
        selectedGenres: Set<Genre> = [],
        yearRange: YearRange? = nil,
        minimumRating: Double = 0.0,
        showWatched: Bool = true,
        showUnwatched: Bool = true
    ) {
        self.selectedGenres = selectedGenres
        self.yearRange = yearRange
        self.minimumRating = minimumRating
        self.showWatched = showWatched
        self.showUnwatched = showUnwatched
    }

    // MARK: - Computed Properties

    /// Returns true if any filter is active
    var isActive: Bool {
        !selectedGenres.isEmpty ||
        yearRange != nil ||
        minimumRating > 0.0 ||
        !showWatched ||
        !showUnwatched
    }

    /// Count of active filters
    var activeCount: Int {
        var count = 0
        if !selectedGenres.isEmpty { count += selectedGenres.count }
        if yearRange != nil { count += 1 }
        if minimumRating > 0.0 { count += 1 }
        if !showWatched || !showUnwatched { count += 1 }
        return count
    }

    // MARK: - Methods

    /// Clear all filters
    mutating func clear() {
        selectedGenres.removeAll()
        yearRange = nil
        minimumRating = 0.0
        showWatched = true
        showUnwatched = true
    }

    /// Convert filters to Jellyfin query parameters
    func toJellyfinQueryParams() -> [String: String] {
        var params: [String: String] = [:]

        // Genres
        if !selectedGenres.isEmpty {
            let genreNames = selectedGenres.map { $0.rawValue }.sorted().joined(separator: ",")
            params["Genres"] = genreNames
        }

        // Year range
        if let range = yearRange {
            if let start = range.start {
                params["Years"] = "\(start)"
            }
            if let end = range.end {
                // If we have both start and end, create range
                if let start = range.start, start != end {
                    params["Years"] = "\(start),\(end)"
                } else if range.start == nil {
                    params["Years"] = "\(end)"
                }
            }
        }

        // Minimum rating
        if minimumRating > 0.0 {
            params["MinCommunityRating"] = String(minimumRating)
        }

        // Watched status
        if showWatched != showUnwatched {
            params["IsPlayed"] = showWatched ? "true" : "false"
        }

        return params
    }
}

// MARK: - Year Range

struct YearRange: Codable, Equatable {
    var start: Int?
    var end: Int?

    init(start: Int? = nil, end: Int? = nil) {
        self.start = start
        self.end = end
    }

    var displayText: String {
        if let start = start, let end = end {
            if start == end {
                return "\(start)"
            }
            return "\(start)-\(end)"
        } else if let start = start {
            return "\(start)+"
        } else if let end = end {
            return "Up to \(end)"
        }
        return "Any year"
    }
}
