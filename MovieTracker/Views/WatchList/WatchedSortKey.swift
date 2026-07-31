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
