//
//  WatchedSortKey.swift
//  MovieTracker
//
//  Sort key available for the Watched list (other lists always sort by release date).
//

import Foundation

enum WatchedSortKey: String {
    case releaseDate
    case dateWatched

    var title: String {
        switch self {
        case .releaseDate: return "Release Date"
        case .dateWatched: return "Date Watched"
        }
    }
}

/// Sort key available for the Watch List and custom lists: by the movie's release
/// date, or by when it was added to the list. Persisted per-list on `MediaList`.
enum ListSortKey: String {
    case releaseDate
    case dateAdded

    var title: String {
        switch self {
        case .releaseDate: return "Release Date"
        case .dateAdded: return "Date Added"
        }
    }
}
