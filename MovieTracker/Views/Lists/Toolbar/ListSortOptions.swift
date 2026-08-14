//
//  ListSortOptions.swift
//  MovieTracker
//

import Foundation

enum WatchedSortKey: String {
    case releaseDate
    case dateWatched
    case rating

    var title: String {
        switch self {
        case .dateWatched: return "Date Watched"
        case .releaseDate: return "Release Date"
        case .rating: return "Rating"
        }
    }

    var symbol: String {
        switch self {
        case .releaseDate: return "popcorn.fill"
        case .dateWatched: return "calendar.badge.checkmark"
        case .rating: return "star.fill"
        }
    }
}

enum ListSortKey: String {
    case releaseDate
    case dateAdded

    var title: String {
        switch self {
        case .releaseDate: return "Release Date"
        case .dateAdded: return "Date Added"
        }
    }

    var symbol: String {
        switch self {
        case .releaseDate: return "popcorn.fill"
        case .dateAdded: return "calendar.badge.plus"
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
