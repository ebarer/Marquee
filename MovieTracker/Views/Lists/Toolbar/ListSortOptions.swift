//
//  ListSortOptions.swift
//  MovieTracker
//

import Foundation

/// Shared by the two sort keys so one menu row builder covers both.
protocol SortKey: Equatable {
    var title: String { get }
    var symbol: String { get }
    /// The order applied when this key is picked: latest/highest first for dates and ratings, A→Z for titles.
    var defaultAscending: Bool { get }
}

enum WatchedSortKey: String, SortKey {
    case releaseDate
    case dateWatched
    case rating
    case alphabetical

    var title: String {
        switch self {
        case .dateWatched: return "Date Watched"
        case .releaseDate: return "Release Date"
        case .rating: return "Rating"
        case .alphabetical: return "Title"
        }
    }

    var symbol: String {
        switch self {
        case .releaseDate: return "popcorn.fill"
        case .dateWatched: return "calendar.badge.checkmark"
        case .rating: return "star.fill"
        case .alphabetical: return "textformat"
        }
    }

    var defaultAscending: Bool {
        switch self {
        case .alphabetical: return true
        case .dateWatched, .releaseDate, .rating: return false
        }
    }
}

enum ListSortKey: String, SortKey {
    case releaseDate
    case dateAdded
    case rating
    case alphabetical

    var title: String {
        switch self {
        case .releaseDate: return "Release Date"
        case .dateAdded: return "Date Added"
        case .rating: return "Rating"
        case .alphabetical: return "Title"
        }
    }

    var symbol: String {
        switch self {
        case .releaseDate: return "popcorn.fill"
        case .dateAdded: return "calendar.badge.plus"
        case .rating: return "star.fill"
        case .alphabetical: return "textformat"
        }
    }

    var defaultAscending: Bool {
        switch self {
        case .releaseDate, .alphabetical: return true
        case .dateAdded, .rating: return false
        }
    }
}

/// Which media a list shows. Surfaced as a single "View" picker (Movies / TV Shows / Both).
enum MediaTypeFilter: String, CaseIterable {
    case all
    case movies
    case tv

    var title: String {
        switch self {
        case .all: return "All"
        case .movies: return "Movies"
        case .tv: return "TV Shows"
        }
    }

    var symbol: String {
        switch self {
        case .all: return "rectangle.stack.badge.play"
        case .movies: return "film"
        case .tv: return "tv"
        }
    }

    func matches(_ type: MediaType) -> Bool {
        switch self {
        case .all: return true
        case .movies: return type == .movie
        case .tv: return type == .tv
        }
    }
}
