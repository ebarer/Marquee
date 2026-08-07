//
//  WatchedSortKey.swift
//  MovieTracker
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
