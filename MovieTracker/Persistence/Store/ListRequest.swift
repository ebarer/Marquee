//
//  ListRequest.swift
//  MovieTracker
//

import Foundation

/// Which list the Lists screen loads.
enum ListRequest: Sendable, Equatable {
    case list(UUID, byDateAdded: Bool, foldOlder: Bool)
    case watched(sort: WatchedSortKey)
    case viewed
}
